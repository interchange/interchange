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
# Interchange session expiration for all catalogs
#
# $Id: expireall.PL,v 2.0.2.3 2003-01-24 06:51:53 jon Exp $
#
# Copyright (C) 1996-2003 Red Hat, Inc. and
# Interchange Development Group, http://www.icdevgroup.org/
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

# $Id: expireall.PL,v 2.0.2.3 2003-01-24 06:51:53 jon Exp $

=head1 DESCRIPTION

Skeleton POD to avoid make errors.

=head1 SEE ALSO

expire(1), http://www.icdevgroup.org/


=cut
_EoP_
	s{.*\n(#(.*)~_~(\w+)~_~(.*))}{$2 . doit($3) . "$4\n$1"}eg;
	my $file = $0;
	$file =~ s/\.PL$//;
	open(OUT, ">$file") 
		or die "Create $file: $!\n";
	print OUT $_;
}
