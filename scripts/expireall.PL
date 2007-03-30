#!/usr/bin/perl
##!~_~perlpath~_~
#
# Interchange session expiration for all catalogs
#
# $Id: expireall.PL,v 2.6.2.1 2007-03-30 12:15:51 pajamian Exp $
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

use lib '/usr/local/interchange/lib';
#use lib '~_~INSTALLPRIVLIB~_~';
use lib '/usr/local/interchange';
#use lib '~_~INSTALLARCHLIB~_~';

use strict;
use Getopt::Std;
use vars qw/$opt_e $opt_f $opt_n $opt_r/; 


BEGIN {
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

my $prog = $0;
$prog =~ s:.*/::;

my $USAGE = <<EOF;
usage: $prog [-r] [-f file]

    -f    Alternate interchange.cfg file
    -n    Do not unlink files
    -r    Use reorganize parameter in command

Expire all listed Interchange catalogs. Will read information from
either the file passed with -f or:

    $Global::VendRoot/interchange.cfg

EOF

use Vend::Config;

$Vend::ExternalProgram = 1;
$Vend::Quiet = 1;

getopts('e:f:rn') or die "$@\n$USAGE\n";

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

my @cats;

if ($opt_r) {
	$flag .= ' -r';
}

if($opt_e) {
	$flag .= qq{ -e "$opt_e"};
}

unless ($opt_n) {
	$flag .= " -u";
}

# Parse the interchange.cfg file to look for script/catalog info
# but don't read in the core tags
$Vend::ControllingInterchange = 1;
chdir $Global::VendRoot or die "Couldn't change to $Global::VendRoot: $!\n";
global_config();

while( my($name, $cat) = each %Global::Catalog ) {
	next if $cat->{base};
	push @cats, $name;
}

for(@cats) {
	system "$Global::VendRoot/bin/expire $flag -c $_";
}

=head1 NAME

expireall -- Run Interchange expire on all catalogs

=head1 VERSION

# $Id: expireall.PL,v 2.6.2.1 2007-03-30 12:15:51 pajamian Exp $

=head1 DESCRIPTION

Skeleton POD to avoid make errors.

=head1 SEE ALSO

expire(1), http://www.icdevgroup.org/


=cut
