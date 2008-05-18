#!/usr/bin/perl -w
##!~_~perlpath~_~
#
# Interchange version 5.5.3
#
# $Id: interchange.PL,v 2.105 2008-05-06 17:14:42 jon Exp $
#
# Copyright (C) 2002-2008 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
# http://www.icdevgroup.org/
#
# This program was originally based on Vend 0.2 and 0.3
# Copyright 1995 by Andrew M. Wilcox <amw@wilcoxsolutions.com>
#
# See the files 'README' and 'WHATSNEW' for information.
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

use strict;

BEGIN {
	if ($ENV{INTERCHANGE_INSTALLPRIVLIB}) {
		unshift @INC, $ENV{INTERCHANGE_INSTALLPRIVLIB};
	}
	else {
		unshift @INC, '/usr/local/interchange/lib';
#		unshift @INC, '~_~INSTALLPRIVLIB~_~';
	}

	if ($ENV{INTERCHANGE_INSTALLARCHLIB}) {
		unshift @INC, $ENV{INTERCHANGE_INSTALLARCHLIB};
	}
	else {
		unshift @INC, '/usr/local/interchange';
#		unshift @INC, '~_~INSTALLARCHLIB~_~';
	}
}

use Config;
no Config;

BEGIN {
	require 5.008;

	$ENV{PERL_SIGNALS} ||= 'unsafe';

	$Global::Foreground = 1;
	
	($Global::VendRoot = $ENV{MINIVEND_ROOT})
		if defined $ENV{MINIVEND_ROOT};

	no warnings 'void';
	## This should only happen in "make test"
	if($Global::VendRoot =~ m{/blib$}) {
		shift @INC;
		shift @INC;
	}
	
	$Global::VendRoot = $Global::VendRoot || '/usr/local/interchange';
#	$Global::VendRoot = $Global::VendRoot || '~_~INSTALLARCHLIB~_~';

	if( ($Config{usethreads} || $Config{useithreads} || $Config{use5005threads}) ) {
		$Global::TryingThreads = 1;
	}

	if( $Global::TryingThreads and $] < 5.008_005 ) {
		die "Interchange will not work with a thread-enabled perl older than Perl 5.8.5.\n";
	}

	if(-f "$Global::VendRoot/interchange.cfg") {
		$Global::ExeName = 'interchange';
		$Global::ConfigFile = 'interchange.cfg';
	}
	elsif(-f "$Global::VendRoot/minivend.cfg") {
		$Global::ExeName = 'minivend';
		$Global::ConfigFile = 'minivend.cfg';
	}
	else {
		$Global::ExeName = 'interchange';
		$Global::ConfigFile = 'interchange.cfg';
	}

	$Global::InitialErrorFile = $Global::ErrorFile = "$Global::VendRoot/error.log";

	if($^O =~ /cygwin|win32/i) {
		$Global::Windows = 1;
	}

	# Uncomment next line if you want to guarantee use of DB_File
	#$ENV{MINIVEND_DBFILE} = 1;

	# Uncomment next line in the unlikely event you want to ignore
	# GDBM and DB_File and force use of SDBM.
	#$ENV{MINIVEND_SDBM} = 1;

	# Uncomment next line if you want to guarantee use of GDBM and not DB_File
	#$ENV{MINIVEND_GDBM} = 1;

	# Uncomment next line if you want to use no DBM, sessions
	# stored in files and databases in memory (or SQL)
	#$ENV{MINIVEND_NODBM} = 1;

	# Uncomment next line if you want the ability to use ALL DBM.
	# Otherwise we use only the first choice to save memory.
	#$ENV{MINIVEND_ALLDBM} = 1;

	# Uncomment next line if you DON'T want to use DBI, can
	# save a bit on code size
	#$ENV{MINIVEND_NO_DBI} = 1;

	# Uncomment next line if you want to use the Storable
	# module for storing session data. It improves session performance
	# to a good degree. We will also do a bit of auto-detect below.
	#$ENV{MINIVEND_STORABLE} = 1;

	# Uncomment next line if you want to use the Storable
	# module for storing database data. It improves GBDM/DB_File performance
	# to a good degree. We will also do a bit of auto-detect below.
	#$ENV{MINIVEND_STORABLE_DB} = 1;

	# Uncomment AND SET next line to set PGP path to somewhere besides
	# the Interchange user path
	#$ENV{PGPPATH} = '/usr/local/pgp';

	# Use the Storable module for storing data in DBM files.
	if(-f "$Global::VendRoot/_session_storable") {
		$ENV{MINIVEND_STORABLE} = 1;
	}

	if(-f "$Global::VendRoot/_db_storable") {
		$ENV{MINIVEND_STORABLE_DB} = 1;
	}

	# Interchange can use syslog via the "logger" command
	# This prevents parsing of the value, default is syslog off
	$Global::SysLog		= '';
}

### END CONFIGURATION VARIABLES

use vars qw($VERSION);
require Exporter;

BEGIN {
	$VERSION = '5.5.3';
}

use Fcntl;

# BSD, among others, defines sendmail to be in /usr/sbin, and
# we want to make sure the program is there. Insert the location
# of you sendmail binary (the configure script should do this)
$Global::SendMailLocation = '' if ! $Global::SendMailLocation;
$Global::SendMailLocation = ($Global::Windows and $Global::SendMailLocation) ||
	($Global::SendMailLocation and -x $Global::SendMailLocation and $Global::SendMailLocation) ||
	(-x '/usr/sbin/sendmail' and '/usr/sbin/sendmail') ||
	(-x '/usr/lib/sendmail' and '/usr/lib/sendmail') ||
	'';
#	'~_~sendmail~_~';

#select a DBM

BEGIN {
	$Global::GDBM = $Global::DB_File = $Global::SDBM =
# LDAP
	$Global::LDAP =
# END LDAP
# SQL
	$Global::DBI =
# END SQL
    $Global::Shadow = 
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
	require Vend::Table::Shadow;
}


use Vend::Util;
use Vend::File;
use Vend::Server;
use Vend::Session;
use Vend::Config;
use Vend::Payment;
use Vend::Ship;

# You might try commenting out these lines and uncommenting the ones
# below to compact memory size
# NOAUTOUSE
use Vend::Order;
#use Vend::Imagemap;
#use Vend::Error;
#use Vend::Control;
# END NOAUTOUSE


# You might try commenting out these lines and uncommenting the ones
# below to do development or test for strange problems
# AUTOUSE
use autouse 'Vend::Error' => qw/get_locale_message interaction_error do_lockout full_dump/;
use autouse 'Vend::Imagemap' => qw/action_map/;
use autouse 'Vend::Control' => qw/
											signal_reconfig
											signal_add
											signal_jobs
											signal_remove
											control_interchange
											remove_catalog
											add_catalog
											change_catalog_directive
											change_global_directive
									/;
#use autouse 'Vend::Order' => qw/
#											add_items
#											check_order
#											check_required
#   										encrypt_standard_cc
#   										mail_order
#   										onfly
#   										route_order
#   										validate_whole_cc
#   								/;

# END AUTOUSE

use Vend::Scan;
use Vend::Data;
use Vend::UserDB;
use Vend::Interpolate;
use Vend::Page;
use Vend::CounterFile;
use Vend::Dispatch;

if($ENV{INTERCHANGE_REQUIRE}) {
	my @mods = split /[;\s]+/, $ENV{INTERCHANGE_REQUIRE};
	foreach my $mod (@mods) {
		eval {
			eval "require $mod";
			die $@ if $@;
		};
		if($@) {
			die errmsg(
				"FAILED to require module %s as specified in environment. Error: %s\n", 
				$mod,
				$@,
			);
		}
		else {
			warn errmsg(
				"Required module %s successfully as specified in environment.\n", 
				$mod,
			);
		}
	}
}

if( ! $Global::Windows and $> == -1 || scalar(getpwuid($>)) eq 'nobody' ) {
	warn errmsg("\aYou probably don't want to run as nobody!\n");
	sleep 1;
	warn errmsg("The security problems are on your head, though. Continuing...\n");
}

## This was set to 1 in Vend::Config, so that external programs calling it
## would act properly by default
undef $Vend::ExternalProgram;

## DEBUG

sub dontwarn {

	$Global::Shadow +
	$Vend::JobsJob +
	$Vend::Interpolate::MAIL +
	$Vend::Server::RUNDIR +

	1;
}

sub version {
	print "Interchange version $VERSION copyright 2002-2008 Interchange Development Group and others.\n";
}

=head1 NAME

interchange - an e-commerce and general HTTP database display system

=head1 SYNOPSIS

interchange [--options] [file]

=head1 VERSION

5.5.3

=head1 DESCRIPTION

Interchange is a database access and retrieval system focused on e-commerce.
It allows customers to select items to buy from catalog pages. The program
tracks user information in sessions and interacts with an HTTP server
through sockets.

Interchange has many, many, functions and features; they are too numerous
to describe in this venue. Complete information can be found at
its web site:

		http://www.icdevgroup.org/

Interchange requires Perl 5.8.0 or higher; more information on Perl can
be seen at:

		http://www.perl.com/

=head1 OPTIONS

Interchange uses the Getopt::Long module, and most options will be recognized
if they uniquely identifiable. The canonical forms are:

=over 4 

=item -a, --add

Add a catalog to the system. Information taken from the input file
(or standard input). Implies reconfig=catalog. Example:

  echo "Catalog simple /catalogs/simple /simple.cgi" | bin/interchange -a

The information is in the form of a standard Interchange catalog line,
and must be in the single-line format.

=item --runjobs=catalog[=job]

Run a jobs group which is a series of files in a directory with
the name corresponding to the C<job>. For instance, if you 
set up a directory called "weekly" in your pages directory
for the catalog C<foundation>, you can run those files with:

	interchange --runjobs=foundation=weekly

Files ending in .html (or whatever HTMLsuffix is for that catalog)
are skipped. It is not tree-recursive -- directories are ignored.

Results can be emailed to an address if you specify --email=address,
and they will be put in the jobs log file.

Alternatively jobs can be specified with --jobgroup=jobname B<before>
the --runjobs option. In other words, this will work:

	interchange --jobgroup=weekly --runjobs=foundation

This will NOT work:

	interchange --runjobs=foundation --jobgroup=weekly

=item -d dir, --dir=dir

Directory for VendRoot. This is where the Interchange configuration file
will be looked for (if not redefined with C<-f>), and where the log file
will go (if not redefined with the ErrorFile directive).

=item -e name, --exclude=name

Exclude catalog from this startup.

=item -email=address

Email address to email jobs results to.

=item -f file, --config=file

Configuration file to use (default is interchange.cfg in VendRoot).

=item -h, --help

Display help on command line options.

=item -i, --inetmode

Run with internet-domain socket only. Normally Interchange runs with
both UNIX- and internet-domain sockets (except on Windows).

=item --jobgroup=job

Sets the job for --runjobs if that is not included in the --runjobs
call. MUST precede the --runjobs entry on the command line.

	interchange --jobgroup=weekly --runjobs=foundation

See --runjobs for an explanation of what this does.

=item --kill [signal]

By default, kills the server ungracefully with signal KILL (9, usually).
The optional signal will be sent instead if supplied.

=item -q, --quiet

Suppress informational messages on startup. Only errors are shown.

=item --reconfig=name

Cause only catalog C<name> to re-read its configuration.

=item --remove=catalog

Remove a catalog from operation; any future requests will get a not-found
message.

=item -r, --restart

Stop and restart the server. This may take a long time if many catalogs
are in use, and will temporarily take the system offline. If you want to
change a UserTag, use the --add option instead.

=item --serve

This is the default if no mode options (--reconfig, --kill, --restart, etc.)
are supplied.

=item --stop

Stop server gracefully with a TERM signal.

=item -t, --test

Report problems with config files; causes a complete configuration of 
the Interchange server but no server start.

=item -u, --unix

Run with unix-domain socket only. Normally Interchange runs with
both UNIX- and internet-domain sockets. This will not work on Windows.

=item -v, --version

Display program version.

=item --DEBUG=1

Set to true value to run foreground in debug mode. It is normal to
receive warnings about various things if you run with perl -w.

=cut

=item Directive=value

Set a Interchange global directive upon start (or --restart). Example:

	interchange SocketPerms=0666

This will start the server and override the default of SocketPerms or the
value set in interchange.cfg for this instance only. Any --restarts must
re-specify the directive if it is still to have that value.

=item name:Directive=value

Set a Interchange directive for catalog C<name> upon start (or --restart). Example:

	interchange simple:VendURL="http://localhost/cgi-bin/simple"

This will start the server and override the default of VendURL for the
value set in catalog.cfg for this instance only. Any --restarts must
re-specify the directive if it is still to have that value.

=back

=cut

sub usage {
	version();
	print <<'END';

Interchange comes with ABSOLUTELY NO WARRANTY.  This is free software, and
you are welcome to redistribute and modify it under the terms of the
GNU General Public License.

Command line options (first letter will usually work):

     --add=catalog         add a catalog to operation; parms taken from the
                           standard input as a "Catalog ..." directive
     -d dir, --dir=dir     directory for VendRoot (interchange.cfg, error.log, etc.)
     -e name,
        --exclude=name     exclude catalog
     --email=emailaddr     Send results of cron job to emailaddr
     -f file,
        --config=file      configuration file (default interchange.cfg)
     --files spec          filespec (perl regexp OK) for static page tree
     -h, --help            display this message
     -i, --inetmode        run with Internet-domain socket (TCP)
     --jobgroup=jobname    job group to run (hourly, daily, weekly, etc.)
     --kill [signal]       kill server ungracefully (9 or with optional signal)
     -q, --quiet           suppress informational messages on startup
     --reconfig=catalog    reconfig a particular catalog on the server
     --remove=catalog      remove a catalog from operation
     -r, --restart         restart server
     --runjobs=catalog[=job]  run jobs for a particular catalog
                           (can use --jobgroup and -email)
     --serve               start server (default) (-start is alias)
     --stop                stop server gracefully
     -t, --test            report problems with config files
     -u, --unix            run with UNIX-domain socket
     -v, --version         display program version
     --DEBUG=1             run foreground in debug mode
END
}

## MAIN

sub catch_warnings {
	unless($_[0]) {
		$SIG{'__WARN__'} = '';
		return;
	}
	$SIG{'__WARN__'} = sub {
		return @_ unless $_[0] =~ /^Use of uninitialized /;
		my $warn = $_[0];
		my $configline;
		if($warn =~ /CONFIG>\s+chunk\s+(\d+)/) {
			return <<EOF;
There is a possible problem in this catalog at line $configline
of the catalog.cfg file. Please check it out.
EOF
		}
		return @_;
	};
}

sub parse_options {

	use Getopt::Long;

	Getopt::Long::config(qw/permute/);

	#Getopt::Long::config(qw/debug/);
	my $rcfgsub = sub {
						my ($mode, $val) = @_;
						die "Can't set two modes -$mode and -$Vend::mode.\n"
								if $Vend::saw_mode;
						$Vend::Quiet = 1
							unless defined $Vend::Quiet;
						$Vend::saw_mode = 1;
						push @Vend::CatalogToReconfig, $val;
						$Vend::mode = $mode;
					};
	my $modesub = sub {
						my ($mode, $val) = @_;
						die "Can't set two modes -$mode and -$Vend::mode.\n"
								if $Vend::saw_mode;
						$Vend::saw_mode = 1;
						$Vend::mode = $mode;
					};

	my ($c_direc, $g_direc);

	my @args = @ARGV;
	my $ignore = 0;

	my %optctl = (

		DEBUG 		    => \$Global::DEBUG,
		reconfig        => $rcfgsub,
		confdir         => \$Global::ConfDir,
		rundir          => \$Global::RunDir,
		configfile      => \$Global::ConfigFile,
		dir          	=> \$Global::VendRoot,
		exclude         => \%Vend::CatalogToSkip,
		help            => sub { usage(); exit 0 },
		inetmode        => \$Global::Inet_Mode,
		log             => \$Global::ErrorFile,
		quiet			=> \$Vend::Quiet,
		pidfile			=> \$Global::PIDfile,
		soappidfile		=> \$Global::SOAP_PIDfile,
		serve           => $modesub,

		test			=> $modesub,
		globalconfig	=> sub { $Vend::Quiet = 1; $modesub->('globalconfig') },
		unixmode        => \$Global::Unix_Mode,
		version         => sub { version(); exit 0 },
		stop			=> \&control_interchange,
		add				=> \&signal_add,
		email 			=> \$Vend::JobsEmail,
		flag			=> \$Vend::JobsFlag,
		jobgroup		=> \$Vend::JobsJob,
		runjobs			=> \&signal_jobs,
		remove			=> \&signal_remove,
		kill			=> \&control_interchange,
		Ignore 			=> \$ignore,
		restart			=> sub {
								return if $ignore;
								$ignore = 1;
								control_interchange('stop', 'TERM', 1);
								sleep 3;
								exec $0, '--Ignore', @args;
							},
		'<>'			=> sub {
							my ($arg) = @_;
							return unless $arg =~ /=/;
							my ($opt, $val) = split /=/, $arg, 2;
							my $cat;
							if($opt =~ /:/) {
								($cat, $opt) = split /:/, $opt, 2;
							}

							my $direc;
							if($cat) {
								$c_direc = Vend::Config::catalog_directives()
									unless $c_direc;
								$direc = $c_direc;
							}
							else {
								$g_direc = Vend::Config::global_directives()
									unless $g_direc;
								$direc = $g_direc;
								$cat = 'mv_global';
							}
							my $found;

							for (@$direc) {
								next unless (lc $opt) eq (lc $_->[0]);
								$found = $_->[0];
								last;
							}
							unless ($found) {
								warn "Unrecognized directive '$arg', skipping.\n";
								return;
							}

							$MV::Default{$cat} = {},
							$MV::DefaultAry{$cat} = []
								unless $MV::Default{$cat};
							$MV::Default{$cat}{$found} = $val
								unless defined $MV::Default{$cat}{$found};
							push @{$MV::DefaultAry{$cat}}, "$found $val";
							return;
							},
	);

	my @options = ( qw/
		DEBUG:i
		Ignore
		add|a=s
        confdir=s
        configfile|config|c|f=s
        dir|vendroot|d=s
        email=s
        exclude|e=s
        flag=i
		help|h
		globalconfig
        inetmode|inet|i
        jobgroup=s
        kill:s
        log|logfile|l=s
        quiet|q
        rundir=s
		runjobs=s
		pidfile=s
		reconfig=s
		remove=s
		restart|r
		serve|start|s
		stop:s
		test|t
		unixmode|unix
		version|v
		<>
	/ );

	GetOptions(\%optctl, @options);

}

# This routine is called at startup. It performs the program and
# catalog configuration functions, to wit:
#
#   --- seed random generator
#   --- set up a couple of preloaded arrays
#   --- parse command-line options
#   --- read global configuration file interchange.cfg and
#       get catalog definitions
#   --- configure each catalog and store its configuration
#       in a reference mapped to the SCRIPT_NAME or catalog name
#   --- determine the program mode, and if it is to begin daemon
#       operation, run the Vend::Server::run_server() routine.
#   --- If Vend::Server::run_server() is entered, that will
#       never exit until a signal is sent
#
sub main_loop {
	# Setup
	unless ($Global::Windows) {
		$ENV{'PATH'} = '/bin:/usr/bin';
		$ENV{'SHELL'} = '/bin/sh';
		$ENV{'IFS'} = '';
	}
	# Initially seed the random generator
	srand;

	# Set up a couple of arrays
	setup_escape_chars();

	# These are only starting values, can be changed by command-line
	# options or the interchange.cfg file
	$Global::ConfDir = "$Global::VendRoot/etc";
	$Global::RunDir = "$Global::VendRoot/etc";
	$Global::PIDfile = "$Global::RunDir/$Global::ExeName.pid";
	$Global::SOAP_PIDfile = "$Global::RunDir/$Global::ExeName.soap.pid";

	$Vend::mode = 'serve';      # mode will be reset by options if appropriate

	# Parse command line options, getting mode if not -serve
	# May actually exit in some situations
	parse_options()
		or usage(), die "\n";

	# Cannot run as root unless in 'make test'
	if($> == 0 and ! $Global::Windows) {
		die errmsg("The Interchange server must not be run as root.\n")
			unless $ENV{MINIVEND_ROOT} =~ m{/blib$};
	}

# LEGACY
	# Kept here for compatibility
	eval {
		require Vend::Payment::CyberCash;
	};
# END LEGACY

	# These modules no longer necessary, why take up memory?
	delete $INC{'Getopt/Long.pm'};

	$Global::ErrorFile = "$Global::VendRoot/error.log"
		if $Global::ErrorFile eq $Global::InitialErrorFile;
	undef $Global::InitialErrorFile;

	chdir($Global::VendRoot) 
		or die "Couldn't change directory to $Global::VendRoot: $!\n";
	$Global::ConfigFile = "$Global::VendRoot/$Global::ExeName.cfg"
		if ! $Global::ConfigFile;

	die "Interchange not configured, no $Global::ConfigFile.\n"
		unless -f $Global::ConfigFile;

	if(! $Global::DEBUG) {
		$Global::DEBUG = $ENV{MINIVEND_DEBUG} || 0;
	}

print errmsg("\n##### DEBUG MODE, running in foreground #####\n") if $Global::DEBUG;

	# Restrictive file permissions to begin with
	umask 077;

	# Read interchange.cfg (or whatever its name is set to be)
	global_config();

	if($Vend::mode eq 'globalconfig') {
		print Vend::Util::uneval($Global::Structure);
		exit;
	}
	# Select locking mode
	set_lock_type();

	Vend::Dispatch::update_global_actions();

#::logDebug(::uneval(\%Global::Catalog));

	# This is only gotten to if -reconfig passed in on command line
	if($Vend::mode eq 'reconfig') {
		eval {
			signal_reconfig(@Vend::CatalogToReconfig);
		};
		die "$@\n" if $@;
		exit;
	}

	$| = 1;
	logGlobal( "Interchange V$VERSION");

	SIGNALCHECK: {
		my $high_enough;
		eval {
			require 5.8.2;
			$high_enough = 1;
		};
		last SIGNALCHECK unless $high_enough;
		if($ENV{PERL_SIGNALS} and $ENV{PERL_SIGNALS} eq 'unsafe') {
			logGlobal("Running with old signals.");
		}
		else {
			my $msg = <<EOF;
Running with new signals, external programs could be unreliable.
Re-run with environment variable PERL_SIGNALS set to "unsafe" to change this.
EOF
			chomp $msg;
			logGlobal($msg);
		}
	}

	THREADCHECK: {
		last THREADCHECK unless $Global::TryingThreads;
		$] >= 5.008_008 and last THREADCHECK;
		
		my $msg = <<EOF;
***************************************************************
***************************************************************
****                                                       ****
****  You are running a Perl with threads enabled -- this  ****
****  is not recommended for a production environment.     ****
****                                                       ****
****  If the Interchange daemon does not start, add this   ****
****  line to interchange.cfg:                             ****
****                                                       ****
****    Variable MV_GETPPID_BROKEN  1                      ****
****                                                       ****
****  Then restart the server.                             ****
****                                                       ****
***************************************************************
***************************************************************
EOF
		chomp $msg;
		logGlobal($msg);
	}

	# The global configuration set up which catalogs exist.
	# Certain ones may have been skipped with -skip on command line...
	CATCONFIG: {
		my $i = 0;
		my ($g, $c, $name);
		foreach $name (sort keys %Global::Catalog) {
			$g =  $Global::Catalog{$name};
			next if defined $Vend::CatalogToSkip{$g->{'name'}};
			print "Configuring catalog " . $g->{'name'} . '...'
				unless $Vend::Quiet or $g->{name} eq '_mv_admin';
			if (exists $Global::Selector{$g->{'script'}}) {
				warn "Two catalogs with same script name $g->{'script'}.\n";
				warn "Skipping catalog $g->{'name'}....\n\n";
				next;
			}

			# Set WARN handler to atch certain warnings and maybe elucidate
			catch_warnings(1);

			# This actually configures the catalog
			eval {
				$c = config_named_catalog($name, "at server startup");
			};

			# See if catalog configuration erred in some way....
			if ($@ or ! defined $c) {
				my $msg = $@;
				print "\n$msg\n\a$g->{'name'}: error in configuration. Skipping.\n";
				$msg =~ s/\s+$//;
				$msg = " -- $msg" if $msg;
				logGlobal $g->{'name'} . ": config error$msg. Skipping.";
				undef $Global::Selector{$g->{'script'}};
				next;
			}

			# Reset WARN handler
			catch_warnings(0);

			# Set up the mapping of the main SCRIPT_NAME
			$Global::Selector{$g->{script}} = $c;

			# Set up aliases
			if (defined $g->{alias}) {
				for(@{$g->{alias}}) {
					if (exists $Global::Selector{$_}) {
						warn "Alias $_ used a second time, skipping.\n";
						next;
					}
					elsif (m![^-\w_:~#/.]!) {
						warn "Bad alias $_, skipping.\n";
					}
					$Global::Selector{$_} = $c;
					$Global::SelectorAlias{$_} = $g->{'script'};
				}
			}

			print "done.\n"  unless $Vend::Quiet or $g->{name} =~ /^_/;
		}
	}

	#undef $Global::DumpStructure;

	if ($Vend::mode eq 'serve') {
		undef $Global::Foreground;

		# Here we prepare enter the daemon mode.

		# Set $0 to something pretty for ps(1).
		# This is all done in Vend::Server::set_process_name now.
		Vend::Server::set_process_name($Global::VendRoot);

		# We won't have much output on any of this, but if we get some
		# we want it immediately
		select STDERR; 
		$| = 1;
		select STDOUT;
		$| = 1;

		# This should never return unless killed or a catastrophic error
		Vend::Server::run_server();
	}
	elsif($Vend::mode eq 'test') {
		# Blank by design, this option only tests config files
		# or builds catalogs
	}
	else {
		die "No mode!\n";
	}

}

### This is where we run after the first portion of the initialization
eval { main_loop(); };
if ($@) {
	my($msg) = ($@);
	$Vend::Log_suppress = 1;
	logGlobal( $msg );
	if ($Global::DisplayErrors) {
		print "$msg\n";
	}
	die "$msg\n" if $Global::Foreground;
}

=head1 SEE ALSO

compile_link(1), config_prog(1), configdump(1), dump(1), expire(1),
expireall(1), localize(1), makecat(1), offline(1), restart(1), update(1),
http://www.icdevgroup.org/

=head1 LICENSE

Interchange comes with ABSOLUTELY NO WARRANTY. This is free software, and
you are welcome to redistribute and modify it under the terms of the
GNU General Public License.

=head1 COPYRIGHT

    Copyright (C) 2002-2008 Interchange Development Group
    Copyright (C) 1995-2002 Red Hat, Inc.
    All rights reserved except those granted in the license.

=cut

=head1 AUTHOR

Mike Heins is the primary author of Interchange.

The Interchange Development Group is:

Dan Browning
David Kelly
Davor Ocelic
Ethan Rowe
Gert van der Spoel
Greg Hanson
Jon Jensen
Jonathan Clark
Kevin Walsh
Mark Johnson
Mike Heins
Paul Vinciguerra
Peter Ajamian
Stefan Hornburg (aka Racke), captain
Randy Moore
Ron Phipps
Ton Verhagen

Please do not contact the authors directly for help with the system.
Use the Interchange mail list:

    interchange-users@icdevgroup.org

Information on subscribing to the list, as well as general information and
documentation for Interchange is at:

    http://www.icdevgroup.org/

=head1 ACKNOWLEDGEMENTS

Original author of Vend, ancestor to Minivend and Interchange, was
Andrew Wilcox <amw@wilcoxsolutions.com>. Interchange could never have
come into being without him. Interchange was based on Vend 0.2, with
portions from Vend 0.3; both were produced in 1995.

Contributions to Interchange have been made by:

=cut

# columnize with "sort -u | pr -t -2 | expand -8 | sed 's/^/    /'"

=pod

    Andreas Koenig           Jason Holt
    Bill Carr                Jason Kohles
    Bill Dawkins             Javier Martin
    Bill Randle              Jeff Carnahan
    Birgitt Funk             Jeff Nappi
    Bob Jordan               Jochen Wiedmann
    Brev Patterson           José Mª Revuelto
    Brian Bullen             Jure Kodzoman
    Brian Kosick             Jurgen Botz
    Bruce Albrecht           Keiko
    Cameron Prince           Keith Oberlin
    Chen Naor                Kim Lauritz Christensen
    Christian Mueller        Larry Leszczynski
    Christopher Miller       Marc Austin
    Christopher Thompson     Mark Stosberg
    Dan Busarow              Massimiliano Ciancio
    Dan Helfman              Matthew Schick
    Daniel Thompson          Michael McCune
    Dave Wingate             Michael Wilk
    David Adams              Mike Frager
    Dennis Cronin            Neil Evans
    Don Grodecki             Nelson Ferrari
    Ed LaFrance              Raj Goel
    Frank Bonita             Ray Desjardins
    Frederic Steinfels       Shozo Murahashi
    Gunnar Hellekson         Sonny Cook
    Hamish Bradick           Tim Baverstock
    Hans-Joachim Leidinger   Tom Friedel
    Heinz Wittenbecher       Tommi Laberno
    Hiroyuki Cozy Kojima     Troy Davis
    Ignacio Lizarán          Victor Nolton
    Jack Tsai                William Dan Terry
    and many others

and, of course, the entire Perl team without whom Interchange could not exist.

=cut

$Global::mod_perl ? 1 : 0;

__END__
