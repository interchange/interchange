#!/usr/bin/perl
##!~_~perlpath~_~
#
# Interchange session expiration
#
# $Id: expire.PL,v 2.7 2003-06-18 17:34:47 jon Exp $
#
# Copyright (C) 2002-2003 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
#
# This program was originally based on Vend 0.2 and 0.3
# Copyright 1995-96 by Andrew M. Wilcox <amw@wilcoxsolutions.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

use lib '/usr/local/interchange/lib';
#use lib '~_~INSTALLPRIVLIB~_~';
use lib '/usr/local/interchange';
#use lib '~_~INSTALLARCHLIB~_~';

use strict;
use Fcntl;

BEGIN {
	($Global::VendRoot = $ENV{MINIVEND_ROOT})
		if defined $ENV{MINIVEND_ROOT};
	$Global::VendRoot = $Global::VendRoot || '/usr/local/interchange';
#	$Global::VendRoot = $Global::VendRoot || '~_~INSTALLARCHLIB~_~';
	$ENV{MINIVEND_STORABLE} = 1
		if -f "$Global::VendRoot/_session_storable";
	$ENV{MINIVEND_STORABLE_DB} = 1
		if -f "$Global::VendRoot/_db_storable";

	if(-f "$Global::VendRoot/interchange.cfg") {
		$Global::ExeName = 'interchange';
		$Global::ConfigFile = 'interchange.cfg';
	}
	elsif(-f "$Global::VendRoot/minivend.cfg") {
		$Global::ExeName = 'minivend';
		$Global::ConfigFile = 'minivend.cfg';
	}
	elsif(-f "$Global::VendRoot/interchange.cfg.dist") {
		$Global::ExeName = 'interchange';
		$Global::ConfigFile = 'interchange.cfg';
	}
}

### END CONFIGURATION VARIABLES

$Global::HammerLock = 20;
$Global::ErrorFile = 'error.log';

$Vend::ExternalProgram = 1;
$Vend::Quiet           = 1;
$Vend::SessionName     = 'utility';

#select a DBM

BEGIN {
	$Global::GDBM = $Global::DB_File = $Global::SDBM =
# LDAP
	$Global::LDAP =
# END LDAP
# SQL
	$Global::DBI =
# END SQL
	0;

# SQL
	# This is for standard DBI
	eval {
			die if $ENV{MINIVEND_NODBI};
			require DBI and $Global::DBI = 1
	};
# END SQL
# LDAP
	eval {
		die if $ENV{MINIVEND_NOLDAP};
		require Net::LDAP and $Global::LDAP = 1
	};
# END LDAP

	# Now can use any type of database
	AUTO: {
		last AUTO if 
			(defined $ENV{MINIVEND_DBFILE} and $Global::DB_File = 1);
		last AUTO if 
			(defined $ENV{MINIVEND_SDBM} and $Global::SDBM = 1);
		last AUTO if 
			(defined $ENV{MINIVEND_NODBM});
		eval {require GDBM_File and $Global::GDBM = 1};
		last AUTO if 
			(defined $ENV{MINIVEND_GDBM} and $Global::GDBM = 1);
		last AUTO if
				!   $ENV{MINIVEND_ALLDBM}
				and $Global::GDBM;
		eval {require DB_File and $Global::DB_File = 1};
		last AUTO if
				!   $ENV{MINIVEND_ALLDBM}
				and $Global::GDBM || $Global::DB_File;
		eval {require SDBM_File and $Global::SDBM = 1};
	}

	if($Global::GDBM) {
		require Vend::Table::GDBM;
		import GDBM_File;
		$Global::GDBM = 1;
		$Global::Default_database = 'GDBM'
			unless defined $Global::Default_database;
	}
	if($Global::DB_File) {
		require Vend::Table::DB_File;
		import DB_File;
		$Global::DB_File = 1;
		$Global::Default_database = 'DB_FILE'
			unless defined $Global::Default_database;
	}
	if($Global::SDBM) {
		require Vend::Table::SDBM;
		import SDBM_File;
		$Global::SDBM = 1;
		$Global::Default_database = 'SDBM'
			unless defined $Global::Default_database;
	}
	$Global::Default_database = 'MEMORY'
			unless defined $Global::Default_database;
	require Vend::Table::InMemory;
}

use Vend::Session;
use Vend::Config qw(get_catalog_default global_config parse_time);
use Vend::Util qw/errmsg/;
use Getopt::Std;
use vars qw/$opt_c $opt_r $opt_e $opt_f $opt_u $opt_v $opt_x/;

sub logGlobal {  }
sub logError  {  }
sub logDebug  {  }

sub is_retired {}

my $USAGE = <<EOF;
usage: expire [-r|-u] -c catalog [-e 'SessionExpire']
           or
       expire [-r|-u] [-e 'SessionExpire'] sessionfile [sessionfile.lock]

 OPTIONS
      -c catalog  specify a catalog from interchange.cfg

      -e time     vary expire time from default in catalog.cfg.
                  time is a string like '4 hours' or '2 days'

      -r          reorganize database and recover lost disk space

      -u          unlink files if file-based sessions (otherwise
	              produces "rm -f \$file" suitable for shell
				  scripts)

      -x          produce list of expired files, one per line
EOF

my $catalog;
my $expiretime;
my $reorg;

$Vend::Cfg = { FileCreationMask => 0600 };

getopts('c:e:f:ruvx') or die "$@\n$USAGE\n";

$catalog    = $opt_c || undef;
$expiretime = $opt_e || undef;
$reorg      = $opt_r;

if($opt_f) {
	$Global::ConfigFile = $opt_f;
}
else {
	$Global::ConfigFile = "$Global::VendRoot/$Global::ConfigFile";
}

GETOPT: {

	last GETOPT if $catalog;
	$Vend::Cfg->{SessionDatabase} = shift
		|| die $USAGE;
	$Vend::Cfg->{SessionDatabase} =~ s/\.(gdbm|db)$//;
	$Vend::Cfg->{SessionLockFile} = shift;
	if (defined $Vend::Cfg->{SessionLockFile}) { 
		die <<EOF unless -f $Vend::Cfg->{SessionLockFile};
Session lock file '$Vend::Cfg->{SessionLockFile}' doesn't exist.
Create one if you are sure the Interchange server is down, then try
again.
EOF
	}
	elsif (-f "$Vend::Cfg->{SessionDatabase}.lock") {
		$Vend::Cfg->{SessionLockFile} = 
				"$Vend::Cfg->{SessionDatabase}.lock";
	}
	else {
		my $dir = $Vend::Cfg->{SessionDatabase};
		$dir = s:/?([^/]+)$::;
		my $file = $1 || die $USAGE;
		die "Aborting, no lock files found!\n"
			unless -f "$dir/$file.lock";
	}

} # END GETOPT

die "too many args, aborting.\n" if @ARGV;

my $g;

if(defined $catalog) {
	my($name,$dir,$param);

	# Parse the interchange.cfg file to look for script/catalog info
	# but don't read in the core tags
	$Vend::ControllingInterchange = 1;
	chdir $Global::VendRoot
		or die "Couldn't change to $Global::VendRoot: $!\n";
	global_config();

	$g = $Global::Catalog{$catalog};
	chdir $g->{dir} or die "chdir to $g->{dir}: $!\n";
	eval {$Vend::Cfg = Vend::Config::config(
					$g->{name},
					$g->{dir},
					"$g->{dir}/etc",
					$g->{base} || undef,
					)};
    if ($@) {
        die "$0: Configuration for catalog $catalog failed: $@\n";
    }
}
else {
	$Vend::Cfg->{ScratchDir} = '/tmp';
	$Vend::Cfg->{ErrorFile} = $Global::ErrorFile;
	$expiretime = '1 day' unless defined $expiretime;
}

if($expiretime) {
	$Vend::Cfg->{SessionExpire} = parse_time('SessionExpire', $expiretime);
}

print "$Vend::Cfg->{CatalogName} expire="
    . $Vend::Cfg->{SessionExpire} / 3600
    . " hour" . ($Vend::Cfg->{SessionExpire} > 3600 ? 's' : '') . "\n"
  if $opt_v;


if ($Vend::Cfg->{SessionType} eq 'File'
	or $Vend::Cfg->{SessionType} eq 'NFS') {
	require File::Find;
	my $expire = $Vend::Cfg->{SessionExpire} + 60;
	$expire /= 86400;
	my $wanted;
	my @nuke;
	$wanted = sub {
		return unless -f $_ && -M _ > $expire;
		push @nuke, $File::Find::name;
	};
	require File::Find;
	File::Find::find($wanted, $Vend::Cfg->{SessionDatabase});
	exit unless @nuke;
	if($opt_u) {
		unlink @nuke;
	}
	else {
		my $joiner = $opt_x ? "\n" : "\nrm -f ";
		print "rm -f " unless $opt_x;
		print join $joiner, @nuke;
		print "\n";
	}
	exit;
}

die $USAGE unless defined $Vend::Cfg->{SessionLockFile};

my $db_reorg = $Global::DB_File ? $reorg : undef;

undef $reorg unless $Global::GDBM;

get_session() unless $reorg;
expire_sessions($reorg);
release_session() unless $reorg;

#system "compact ." if $db_reorg;

=head1 NAME

expire -- expire Interchange session files and databases

=head1 VERSION

1.1

=head1 SYNOPSIS

   expire [-ra] [-e expr] [-c catalog] [-d dir] [sessiondb]

=head1 DESCRIPTION

Interchange's C<expire> expires the various session database and temporary
files used by the Interchange daemon.

If the program C<tmpwatch> is available, it is called with the appropriate 
arguments. Otherwise, Interchange will remove all files itself with a recursive
routine.

=head1 OPTIONS

=over 4

=item -c name

Expires the catalog C<name> according to its settings. Removes all temporary
files that are in a subdirectory one level below the directory itself.

=item -d dir

Sets the directory that will be checked for session files and/or temporary
files.

=item -e spec

Accepts a Interchange expire time setting like "6 hours", "3 days", etc.
The expire time is applied directly to sessions, and may be padded for
temporary files.

=back

=head1 SEE ALSO

expireall(1), http://www.icdevgroup.org/

=head1 AUTHOR

Mike Heins

