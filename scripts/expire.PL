#$self = {
#	INSTALLPRIVLIB => '/usr/local/interchange/lib',
#	INSTALLARCHLIB => '/usr/local/interchange',
#};

use Config;
require 'scripts/initp.pl';

sub doit {
	my ($key) = @_;
	my $val;
	if ($MV::Self->{RPMBUILDDIR} and $val = $MV::Self->{$key}) {
		$val =~ s!^$MV::Self->{RPMBUILDDIR}/!/!; 
		return $val;
	}
	return $MV::Self->{$key} unless $key =~ /[a-z]/;
	return $Config{$key};
}

DOIT: {
	local ($/);
	local($_) = <<'_EoP_';
#!/usr/bin/perl
##!~_~perlpath~_~
#
# Interchange session expiration
#
# $Id: expire.PL,v 1.5 2000-09-20 19:58:01 zarko Exp $
#
# Copyright (C) 1996-2000 Akopia, Inc. <info@akopia.com>
#
# This program was originally based on Vend 0.2
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
#
# Portions from Vend 0.3
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
#
# See the file 'Changes' for information.
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

BEGIN {

	($Global::VendRoot = $ENV{MINIVEND_ROOT})
		if defined $ENV{MINIVEND_ROOT};
$Global::VendRoot = $Global::VendRoot || '/usr/local/interchange';
#$Global::VendRoot = $Global::VendRoot || '~_~INSTALLARCHLIB~_~';
	$ENV{MINIVEND_STORABLE} = 1
		if -f "$Global::VendRoot/_session_storable";
	$ENV{MINIVEND_STORABLE_DB} = 1
		if -f "$Global::VendRoot/_db_storable";
	
}

### END CONFIGURABLE VARIABLES

$Global::ConfigFile = 'minivend.cfg';
$Global::HammerLock = 20;
$Global::ErrorFile = 'error.log';

use strict;
use Fcntl;

$Vend::ExternalProgram = 1;
$Vend::SessionName = 'utility';

#select a DBM

BEGIN {
	$Global::GDBM = $Global::DB_File = 0;
    AUTO: {
        last AUTO if
            (defined $ENV{MINIVEND_DBFILE} and $Global::DB_File = 1);
        last AUTO if
            (defined $ENV{MINIVEND_NODBM});
        eval {require GDBM_File and $Global::GDBM = 1} ||
        eval {require DB_File and $Global::DB_File = 1};
    }
	if($Global::GDBM) {
		require Vend::Table::GDBM;
		import GDBM_File;
		$Global::GDBM = 1;
	}
	elsif($Global::DB_File) {
		require Vend::Table::DB_File;
		import DB_File;
		$Global::DB_File = 1;
	}
	else {
		die "Can't use expire without DBM sessions.\n";
	}
}

use Vend::Session;
use Vend::Config qw(get_catalog_default parse_time);
use Vend::Util qw/errmsg/;
use vars qw/$opt_c $opt_r $opt_e $opt_u $opt_v $opt_x/;

$Vend::Quiet = 1;

sub logGlobal {
	ref $_[0] and shift(@_);
	warn(errmsg(@_));
}

sub is_retired {}

my $USAGE = <<EOF;
usage: expire [-r|-u] -c catalog [-e 'SessionExpire']
           or
       expire [-r|-u] [-e 'SessionExpire'] sessionfile [sessionfile.lock]

 OPTIONS
      -c catalog  specify a catalog from minivend.cfg

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

use Getopt::Std;

getopts('c:e:ruvx') or die "$@\n$USAGE\n";

$catalog    = $opt_c || undef;
$expiretime = $opt_e || undef;
$reorg      = $opt_r;

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
	chdir $Global::VendRoot;
	open(GLOBAL, "< $Global::ConfigFile") or
		die "No global configuration file? Aborting.\n";
	while(<GLOBAL>) {
		next unless /^\s*((?:sub)?catalog)\s+($catalog\s+.*)/i;
		Vend::Config::parse_catalog($1, $2);
	}
	close GLOBAL;
	die "Catalog $catalog not found in $Global::ConfigFile.\n"
		unless $Global::Catalog{$catalog};
	$g = $Global::Catalog{$catalog};
	chdir $g->{dir} or die "chdir to $g->{dir}: $!\n";
	$Vend::Cfg = Vend::Config::config(
					$g->{name},
					$g->{dir},
					"$g->{dir}/etc",
					$g->{base} || undef,
					);
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


if ($Vend::Cfg->{SessionType} eq 'File' ) {
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

1.0

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

mvdocs(8), expireall(1), http://www.akopia.com/

=head1 AUTHOR

Mike Heins, <heins@akopia.com>


_EoP_
	s{.*\n(#(.*)~_~(\w+)~_~(.*))}{$2 . doit($3) . "$4\n$1"}eg;
	my $file = $0;
	$file =~ s/\.PL$//;
	open(OUT, ">$file") 
		or die "Create $file: $!\n";
	print OUT $_;
}
