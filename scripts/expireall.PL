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
# Interchange session expiration for all catalogs
#
# $Id: expireall.PL,v 1.8 2000-09-25 16:57:54 zarko Exp $
#
# Copyright (C) 1996-2000 Akopia, Inc. <info@akopia.com>
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
	-r    Use reorganize parameter in command

Expire all listed Interchange catalogs. Will read information from
either the file passed with -f or:

	$Global::VendRoot/interchange.cfg

EOF

getopts('e:f:rn') or die "$@\n$USAGE\n";

($Global::ConfigFile = $opt_f)
	if defined $opt_f;

my $flag = '';
my @cats;

if ($opt_r) {
	$flag .= '-r';
}

if($opt_e) {
	$flag .= qq{ -e "$opt_e"};
}

unless ($opt_n) {
	$flag .= " -u";
}

# Parse the interchange.cfg file to look for script/catalog info
PARSECFG: {
	my(@cfglines,%seen);

	open(GLOBAL, "< $Global::ConfigFile") or die "Couldn't read $Global::ConfigFile: $!\n";
	while(<GLOBAL>) {
		push(@cfglines, $_) if /^\s*catalog\s+/i;
	}
	close GLOBAL;

	@cfglines = grep !$seen{$_}++, @cfglines;

	for(@cfglines) {
		next unless /^\s*(?:sub)?catalog\s+([-\w_]+)/i;
		push(@cats, $1);
	}

}

for(@cats) {
	system "$Global::VendRoot/bin/expire $flag -c $_";
}

=head1 NAME

expireall -- Run Interchange expire on all catalogs

=head1 VERSION

$Id: expireall.PL,v 1.8 2000-09-25 16:57:54 zarko Exp $

=head1 DESCRIPTION

Skeleton POD to avoid make errors.

=head1 SEE ALSO

mvdocs(8), expire(1), http://www.akopia.com/


=cut
_EoP_
	s{.*\n(#(.*)~_~(\w+)~_~(.*))}{$2 . doit($3) . "$4\n$1"}eg;
	my $file = $0;
	$file =~ s/\.PL$//;
	open(OUT, ">$file") 
		or die "Create $file: $!\n";
	print OUT $_;
}
