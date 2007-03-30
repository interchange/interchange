#!/usr/bin/perl
##!~_~perlpath~_~
#
# findtags - Find ITL tags in Interchange catalogs and directories
#
# $Id: findtags.PL,v 1.7 2007-03-30 11:39:56 pajamian Exp $
#
# Copyright (C) 2002-2005 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
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

use lib '/work/interchange/lib';
#use lib '~_~INSTALLPRIVLIB~_~';
use lib '/work/interchange';
#use lib '~_~INSTALLARCHLIB~_~';

use strict;


BEGIN {
	($Global::VendRoot = $ENV{MINIVEND_ROOT})
		if defined $ENV{MINIVEND_ROOT};

	$Global::VendRoot = $Global::VendRoot || '/work/interchange';
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

my $prog = $0;
$prog =~ s:.*/::;

my $USAGE = <<EOF;
usage: $prog [-r] [-f file]

    -a                  Look in all catalogs
    -c CAT              Only look in catalog CAT
    -d "dir1 dir2 .."   Look in dirs
    -f                  Alternate interchange.cfg file
    -h                  Print this message and exit
    -n                  Don't report SystemTag
    -t                  "TagInclude" directive output
    -u                  Report unseen tags
    -v                  Slightly verbose, report directories scanned
    -x "dirs"           Don't look for tags in dir (default "session tmp")

Find tags in Interchange catalogs and directories -- intended to develop
a list for TagInclude.

WARNING: This is not 100%, for developing tag names from Variable definitions
and other sources can fool it. If you include all directories, make sure you
don't include documentation files or the usertags themselves.

With the standard distribution, this should find just about all
tags needed:

	findtags -a -d lib/UI

To develop a TagInclude statement which excludes unused tags, try:

	findtags -a -d lib/UI -t -u

If you don't want to use the UI, then do:

	findtags -a -u -t 

EOF

use Vend::Config;

$Vend::ExternalProgram = 1;
$Vend::Quiet = 1;

use Getopt::Std;
use vars qw/
	$opt_a
	$opt_c
	$opt_d
	$opt_f
	$opt_h
	$opt_n
	$opt_t
	$opt_u
	$opt_v
	$opt_x
/; 

if($ARGV[0] eq '--help') {
	print $USAGE;
	exit 2;
}

getopts('ac:d:f:hntuvx') or die "$@\n$USAGE\n";

if($opt_h) {
	print $USAGE;
	exit 2;
}

sub logGlobal { shift(@_) if ref $_[0]; printf @_; print "\n" }
sub logError { }
sub logDebug { }

my $flag = '';

if($opt_f) {
	$Global::ConfigFile = $opt_f;
	$flag .= qq{ -f "$opt_f"};
}
else {
	$Global::ConfigFile = "$Global::VendRoot/$Global::ConfigFile";
}

# Parse the interchange.cfg file to look for script/catalog info
# but don't read in the core tags
$Vend::ControllingInterchange = 1;
chdir $Global::VendRoot or die "Couldn't change to $Global::VendRoot: $!\n";
global_config();

my @cats;

if($opt_a) {
	while( my($name, $cat) = each %Global::Catalog ) {
		next if $cat->{base};
		push @cats, $name;
	}
}
elsif($opt_c) {
	@cats = split /[\s,]+/, $opt_c;
}

my @exclude = qw/session tmp/;
my %exclude;

if($opt_x) {
	@exclude = split /[\s,]+/, $opt_x;
}

@exclude{@exclude} = @exclude;

my @dirs;

for(@$Global::TagDir) {
	push @dirs, glob("$_/*");
}

#warn "Dirs are " . join (" ", @dirs) . "\n";

if ($opt_n) {
	@dirs = grep $_ !~ '/SystemTag$', @dirs;
}

my %tag;

use File::Find;

GETTAGS: {
	my @tags;
	my $wanted = sub {
		return unless -f $_;
		return unless /^(\w[-\w]*)\.[a-z_]*tag$/;
		my $tname = $1;
		$tname = lc $tname;
		$tname =~ tr/-/_/;
		push @tags, $tname;
	};
	File::Find::find($wanted, @dirs);
	my %seen;
	@tags = grep !$seen{$_}++, @tags;
	@tag{@tags} = @tags;
}

my @targdirs;

if($opt_d) {
	my @d = split /[\s,]+/, $opt_d;
	for(@d) {
warn "Doing directory $_\n" if $opt_v;
		push @targdirs, $_;
	}
}

my @tags;

foreach my $catname (@cats) {
warn "Doing catalog $catname\n" if $opt_v;
	my $dir = $Global::Catalog{$catname}->{dir};
	if(! $dir) {
		warn errmsg("Unknown catalog '%s', skipping.\n", $catname);
	}
	push @targdirs, $dir;
}

if(! @targdirs) {
	die "no directories to scan!\n";
}

foreach my $dir (@targdirs) {
	chdir $dir
		or die errmsg("chdir to directory %s: $!\n", $dir);
	my @files;
	my @binaries;
	my $wanted = sub {
		return unless -f $_;
		if (-B $_) {
			push @binaries, $File::Find::name;
		}
		push @files, $File::Find::name;
	};

	my @d = glob('*');
	@d = grep !$exclude{$_}, @d;
	File::Find::find($wanted, @d);

	undef $/;
	foreach my $f (@files) {
#print "Checking file $f\n";
		open IT, "< $f"			or die errmsg("open %s: %s", $f, $!);
		$_ = <IT>;
		close IT				or die errmsg("close %s: %s", $f, $!);
		while (m{(?:\[(\w[-\w]*)[\s\]]|\$Tag->(\w+))}g) {
			my $tmp = $1 || $2;
			next if $tmp =~ /^\d+$/;
			$tmp =~ s/-/_/g;
			$tmp = lc $tmp;
			next unless $tag{$tmp};
			if($opt_u) {
				delete $tag{$tmp};
			}
			else {
				push @tags, $tmp;
			}
		}
	}
}

my %seen;

if($opt_u) {
	@tags = keys %tag;
	if($opt_t) {
		@tags = map { "!$_" } @tags;
	}
}
else {
	@tags = grep !$seen{$_}++, @tags;
}

@tags = sort grep /\w/, @tags;

if($opt_t) {
	print "TagInclude <<EOTI\n\t";
	print join("\n\t", @tags);
	print "\nEOTI\n";
}
else {
	print join("\n", @tags);
}
__END__

=head1 NAME

findtags - find tags in Interchange catalogs and directories

=head1 SYNOPSIS

  findtags -a -d lib/UI
  findtags -a -d lib/UI -t -u
  findtags -a -u -t 

=head1 DESCRIPTION

Find tags in Interchange catalogs and directories -- intended to develop
a list for TagInclude.

WARNING: This is not 100%, for developing tag names from Variable definitions
and other sources can fool it. If you include all directories, make sure you
don't include documentation files or the usertags themselves.

With the standard distribution, this should find just about all
tags needed:

	findtags -a -d lib/UI

To develop a TagInclude statement which excludes unused tags, try:

	findtags -a -d lib/UI -t -u

If you don't want to use the UI, then do:

	findtags -a -u -t 

=head1 OPTIONS

=over 4

=item -a

Look in all catalogs.

=item -c CAT

Only look in catalog CAT.

=item -d DIR1 DIR2 ....

Look in given directories.

=item -f FILE

Use alternate interchange.cfg file FILE.

=item -h

Display help.

=item -n

Don't report system tags.

=item -t

Output suitable for TagInclude directive.

=item -u

Report unseen tags.

=item -v
  
Slightly verbose, report directories scanned.

=item -x DIR1 DIR2 ....

Exclude given directories from scanning. Default is session and tmp.

