#!/usr/bin/perl
##!~_~perlpath~_~
#
# Interchange database builder and indexer
#
# $Id: offline.PL,v 2.5.2.1 2007-03-30 12:15:51 pajamian Exp $
#
# Copyright (C) 2002-2005 Interchange Development Group
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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

use lib '/usr/local/interchange/lib';
#use lib '~_~INSTALLPRIVLIB~_~';
use lib '/usr/local/interchange';
#use lib '~_~INSTALLARCHLIB~_~';

use strict;
use Fcntl;
use Vend::Util;
use Vend::Config;
use Vend::Data;
use Getopt::Long;
use Data::Dumper;
use File::Copy;

$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 2;

BEGIN {
	eval {
		require 5.004;
		require FindBin;
		1 and $Global::VendRoot = $FindBin::RealBin;
		1 and $Global::VendRoot =~ s/.bin$//;
	};
	($Global::VendRoot = $ENV{MINIVEND_ROOT})
		if defined $ENV{MINIVEND_ROOT};

	$Global::VendRoot = $Global::VendRoot || '/usr/local/interchange';
#	$Global::VendRoot = $Global::VendRoot || '~_~INSTALLARCHLIB~_~';

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

$Global::ErrorFile = "$Global::VendRoot/error.log";
$Vend::ExternalProgram = 1;

#select a DBM

BEGIN {

	$ENV{MINIVEND_STORABLE_DB} = 1 if -e "$Global::VendRoot/_db_storable";
	$Global::GDBM = $Global::DB_File = $Global::DBI = 0;
    # Now can use any type of database
	AUTO: {
		last AUTO if 
			(defined $ENV{MINIVEND_DBFILE} and $Global::DB_File = 1);
		last AUTO if 
			(defined $ENV{MINIVEND_NODBM});
		eval {require GDBM_File and $Global::GDBM = 1};
		last AUTO if 
			(defined $ENV{MINIVEND_GDBM} and $Global::GDBM = 1);
		eval {require DB_File and $Global::DB_File = 1};
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
	
	unless($Global::GDBM || $Global::DB_File || $Global::DBI) {
		die "No DBM or DBI defined! Offline import not necessary.\n";
	}
}

my $USAGE = <<EOF;
usage: offline -c catalog [-d offline_dir]

If specifying a subcatalog, make sure the databases to be built
are defined in the subcatalog definition.  If they are in the base
catalog, use that catalog as the parameter for the -c directive.
EOF

my ($catalog,$directory,$delimiter);
my (@Catalogs);
my (@Directories);
my ($Live, $NoBackup, $Verbose, $BackupExt);

my %optctl = (
			catalog   => \@Catalogs,
			directory => \@Directories,
			live => \$Live,
			backup => \$BackupExt,
			verbose => \$Verbose,
			nobackup => \$NoBackup,
			);

my @options = qw(
			catalog|c=s
			directory|d=s
			live|l
			backup|b=s
			nobackup|n
			verbose|v
			);
GetOptions(\%optctl, @options)
	or die "$@\n\n$USAGE\n";

$BackupExt = '.bak' unless $BackupExt;

die "$USAGE\n" unless @Catalogs;

chdir $Global::VendRoot;

global_config();

$| = 1;

foreach my $name (@Catalogs) {
	my $directory = shift @Directories;
	my $g = $Global::Catalog{$name};
	die "No catalog named $_.\n"
		unless($g);

	my ($dir, $subconfig) = @{$g}{qw/dir base/};
	warn "Probably hard to offline build a subcatalog, but we will try.\n"
		if $subconfig;
	chdir $dir or die "Couldn't change directory to $dir: $!\n";
	$Vend::Cfg = config($name, $dir, 'config', $subconfig || undef);
	$::Variable = $Vend::Cfg->{Variable};
	chdir $dir or die "Couldn't change directory to $dir: $!\n";

	my $realprod = $Vend::Cfg->{ProductDir};
	$Vend::Cfg->{ProductDir} = $directory || $Vend::Cfg->{OfflineDir};

	open_database();

	my $db;
	my $obj;
	$Vend::Quiet = 1;
	foreach $db (keys %{$Vend::Cfg->{Database}}) {
		# Skip SQL and MEMORY databases
		my $config = $Vend::Cfg->{Database}->{$db};
		next if $config->{Class} =~ /MEMORY|DBI/;
		print "Checking $db....";
		eval {
			$obj = database_exists_ref($db)
				or die "Trouble importing $db: $!\n";
			$obj = $obj->ref();
		};
		if($@) {
			my $msg = "Trouble importing $db: $@\n\n";
			if($msg =~ /source.*exist|no.*such.*file/i) {
				print "no source file, skipping.\n";
				next;
			}
			$msg .= Dumper($config) if $Verbose;
			warn "$msg\n";
			next;
		}
		if($Live) {
			print "taking $db live....";
			my $asc_src  = "$config->{dir}/$config->{file}";
			my $dbm_src  = "$config->{db_file}";
			my $asc_targ = "$realprod/$config->{file}";
			my $dbm_targ = $dbm_src;
			$dbm_targ =~ s{^$config->{dir}}{$realprod}
				or die "Couldn't derive DBM target name.\n";
			open(TARG, "+<$asc_targ")
				or die "Couldn't open ASCII file $asc_targ read/write: $!\n";
			lockfile(\*TARG, 1, 1)
				or die "Couldn't lock ASCII file $asc_targ: $!\n";
			open(SRC, "+<$asc_src")
				or die "Couldn't open ASCII file $asc_src read/write: $!\n";
			lockfile(\*SRC, 1, 1)
				or die "Couldn't lock ASCII file $asc_src: $!\n";

			#DBM
			File::Copy::move($dbm_targ, "$dbm_targ$BackupExt")
				or warn "move $dbm_targ --> $dbm_targ$BackupExt: $!\n"
				unless $NoBackup;
			File::Copy::move($dbm_src, $dbm_targ)
					or die "move $dbm_src --> $dbm_targ: $!\n";

			my $now = time();
			#ASC
			File::Copy::move($asc_targ, "$asc_targ$BackupExt")
				or warn "move $asc_targ --> $asc_targ$BackupExt: $!\n"
				unless $NoBackup;
			# Possible race condition, but oh well
			File::Copy::move($asc_src, $asc_targ)
					or die "move $asc_src --> $asc_targ: $!\n";
			utime $now, $now, $asc_targ, $dbm_targ;
			unlockfile(\*TARG);
			unlockfile(\*SRC);
			close SRC;
			close TARG;
		}
		print "done with $db.\n";
	}

	close_database();
}

=head1 NAME

offline -- Interchange offline database builder

=head1 VERSION

# $Id: offline.PL,v 2.5.2.1 2007-03-30 12:15:51 pajamian Exp $

=head1 DESCRIPTION

Skeleton POD to avoid make errors.

=head1 SEE ALSO

interchange(1), http://www.icdevgroup.org/

=cut
