my $base = $ARGV[0] || '/work/interchange';
$self = {
	INSTALLARCHLIB => $base,
	INSTALLBIN     => "$base/bin",
	INSTALLDIRS    => 'perl',
	INSTALLMAN1DIR => "$base/doc",
	INSTALLMAN3DIR => "$base/doc",
	INSTALLPRIVLIB => "$base/lib",
	INSTALLSCRIPT  => "$base/bin",
};

my %Special;

use Config;

eval {
	require 'scripts/initp.pl';
};

if(! $MV::Self ) {
	$MV::Self = $self;
	$Special{perlpath} = $Config{perlpath};
	$Special{perlpath} .= <<EOF;


eval 'exec $Config{perlpath} -S \$0 \${1+"\$@"}'
    if 0; # not running under some shell
EOF
	$Special{perlpath} =~ s/\s+$//;
}


sub doit {
	my ($key) = @_;
	my $val;
	if ($MV::Self->{RPMBUILDDIR} and $val = $MV::Self->{$key}) {
		$val =~ s!^$MV::Self->{RPMBUILDDIR}/!/!; 
		return $val;
	}
	return $MV::Self->{$key} unless $key =~ /[a-z]/;
	return $Special{$key} if defined $Special{$key};
	$Config{$key};
}

DOIT: {
	local ($/);
	local($_) = <<'_EoP_';
#!/usr/bin/perl
##!~_~perlpath~_~
#
# Interchange catalog initialization update and query tool
# inspired by chkconfig(8).
#
# $Id: chkcat.PL,v 1.3 2001-09-12 20:15:59 jon Exp $
#
# Copyright (C) 2001 Red Hat, Inc. <interchange@redhat.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA.

use lib '/usr/local/interchange/lib';
#use lib '~_~INSTALLPRIVLIB~_~';
use lib '/usr/local/interchange';
#use lib '~_~INSTALLARCHLIB~_~';

require 5.005;
use strict;
use Vend::Util;
use Vend::Config;

BEGIN {
	$Global::VendRoot = $ENV{MINIVEND_ROOT} if defined $ENV{MINIVEND_ROOT};

	$Global::VendRoot = $Global::VendRoot || '/usr/local/interchange';
#	$Global::VendRoot = $Global::VendRoot || '~_~INSTALLARCHLIB~_~';

	$Global::ConfigFile = 'interchange.cfg';
}

$Vend::ExternalProgram = 1;

print STDERR <<EOF;
chkcat - Update and query portions of an Interchange catalog's configuration

EOF

my $usage = <<'EOF';
Usage: chkcat [catname|catdir] --[on|off] servicename1 [servicename2 ...]
                              [--[on|off] servicename3 [servicename4 ...]]
       chkcat [catname|catdir] -l|--list
       chkcat -s|--show
EOF

die $usage if ! @ARGV or map { /^-(?:h|-help|\?)$/i } @ARGV;

# find out which catalog we'll be dealing with
my ($error, $showcats, $catdir, $catparm);
$catparm = shift;
# just list all in interchange.cfg and exit
$showcats = \*STDOUT if $catparm =~ /^-(?:s|-show)$/;
if ($showcats or $catparm !~ m:/:) {
	# parse interchange.cfg to get catalog's catroot
	chdir $Global::VendRoot;
	global_config();
	unless ($showcats) {
		if (ref $Global::Catalog{$catparm} eq 'HASH') {
			$catdir = $Global::Catalog{$catparm}->{dir};
			$error = "Unable to find directory '$catdir'." unless -d $catdir;
		} else {
			$error = "Catalog '$catparm' is unknown.";
		}
	}
} else {
	# accept directory name (especially for catalogs not in interchange.cfg)
	$catparm =~ s:/+$::;
	$catdir = $catparm;
	$error = "Unable to find directory '$catdir'." unless -d $catdir;
}

# show configured catalogs if option given, or specified catalog is unknown
if ($showcats or $error) {
	print STDERR $usage, "\n", $error, "\n" if $error;
	print STDERR "Catalogs and locations in interchange.cfg are:\n";
	$showcats = \*STDERR unless ref $showcats eq 'GLOB';
	print $showcats $_, " ", $Global::Catalog{$_}->{dir}, "\n"
		for sort keys %Global::Catalog;
	exit 1;
}

# make sure the new SysV-style configuration directories exist
my $rc_dir = "$catdir/config/rc.d";
my $init_dir = "$catdir/config/init.d";
for (\$rc_dir, \$init_dir) {
	unless (-d $$_) {
		die <<EOF
$usage
Unable to find directory '$$_'.
Does the catalog perhaps not have SysV-style configuration?
EOF
	}
}
my $init_rel = '../init.d';

die $usage unless @ARGV;

my $action = '';
my $list = 0;

# go through command line arguments
for (@ARGV) {
	# if requested, print configuration list after everything else
	($list = 1, next) if /^-l$/ or /^--list$/;
	# select action for coming config arguments
	($action = $1, next) if /^--(on|off)$/;
	if (/^-/) {
		print STDERR "Skipping unknown option '$_'\n";
		next;
	}
	die $usage unless $action eq 'on' or $action eq 'off';

	# find out position in initialization list from each config file itself
	s:.*/::;	# tolerate leading directories
	s/\.cfg$//;	# tolerate full filename with '.cfg'
	s/^S\d+//;	# tolerate symlink names
	my $cfg = $_;
	my $cfgfile = "$init_dir/$cfg.cfg";
	my $header = Vend::Util::get_cfg_header($cfgfile);
	die $header->{error} unless $header->{position};
	my $linkfile = $rc_dir . '/S' . $header->{position} . $cfg;

	# create or remove symlink as appropriate
	if ($action eq 'on') {
		my $relcfg = "$init_rel/$cfg.cfg";
		print STDERR "Creating symlink $linkfile -> $relcfg\n";
		print STDERR "File '$linkfile' exists! Skipping $relcfg.\n"
			if -e $linkfile and ! -l $linkfile;
		unlink $linkfile if -l $linkfile;
		symlink $relcfg, $linkfile
			or die "Error making symlink '$linkfile' to '$relcfg': $!\n";
	} elsif ($action eq 'off') {
		print STDERR "Removing symlink $linkfile\n";
		if (-e $linkfile) {
			unlink $linkfile or die "Error removing symlink '$linkfile': $!\n";
		}
	}
}

print STDERR "\n" if $action;

# output the current config status to STDOUT in an easily parsable format
if ($list) {
	my (%on, %off);

	# first print out configs that are on
	opendir RC_D, $rc_dir or die "Unable to open directory '$rc_dir': $!\n";
	%on = map { s/^S(\d+)//; $_ => $1 } grep { /^S/ and -f "$rc_dir/$_" }
		readdir RC_D;
	closedir RC_D;
	print "$_ on $on{$_}\n" for sort { $on{$a} <=> $on{$b} } keys %on;

	print STDERR "\n";

	# get a list of all configs
	opendir INIT_D, $init_dir or die "Unable to open directory '$init_dir': $!\n";
	$off{$_} = '-' for grep { /^\w+\.cfg$/ && -e "$init_dir/$_" && s/\.cfg$// }
		readdir INIT_D;
	closedir INIT_D;
	# remove those that are on
	delete $off{$_} for keys %on;
	# get the config positions, if available (for user's information only)
	for (keys %off) {
		my $header = Vend::Util::get_cfg_header("$init_dir/$_.cfg");
		$off{$_} = $header->{position} ? $header->{position} : '??';
	}
	# print out configs that are off
	print "$_ off $off{$_}\n" for sort { $off{$a} <=> $off{$b} } keys %off;
}


=head1 NAME

chkcat

=head1 DESCRIPTION

Updates and queries Interchange catalog SysV-style initialization
settings similiar to chkconfig(8).

Text sent to standard output is designed to be easily machine-parsable.

=head1 VERSION

# $Id: chkcat.PL,v 1.3 2001-09-12 20:15:59 jon Exp $

=head1 AUTHOR

Jon Jensen <jon@redhat.com>

=head1 SEE ALSO

interchange(1), http://interchange.redhat.com/

=cut
_EoP_
	s{.*\n(#(.*)~_~(\w+)~_~(.*))}{$2 . doit($3) . "$4\n$1"}eg;
	my $file = $0;
	$file =~ s/\.PL$//;
	open(OUT, ">$file") 
		or die "Create $file: $!\n";
	print OUT $_;
}
