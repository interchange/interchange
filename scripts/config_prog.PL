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
# Interchange program configurator
#
# $Id: config_prog.PL,v 2.0.2.2 2002-11-26 03:21:13 jon Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. and
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
use Config;
use Getopt::Long;

Getopt::Long::config(qw/permute/);

use vars qw/$Self/;

BEGIN {
	$Self = {
		INSTALLPRIVLIB => '/usr/local/interchange/lib',
#		INSTALLPRIVLIB => '~_~INSTALLPRIVLIB~_~',
		INSTALLARCHLIB => '/usr/local/interchange',
#		INSTALLARCHLIB => '~_~INSTALLARCHLIB~_~',
		INSTALLMAN1DIR => '/usr/local/interchange/doc',
#		INSTALLMAN1DIR => '~_~INSTALLMAN1DIR~_~',
		INSTALLSCRIPT => '/usr/local/interchange/bin',
#		INSTALLSCRIPT => '~_~INSTALLARCHLIB~_~/bin',
		INSTALLBIN => '/usr/local/interchange/bin',
#		INSTALLBIN => '~_~INSTALLBIN~_~',
	};
}

### END CONFIGURATION VARIABLES

my $prog = $0;
$prog =~ s:.*/::;
my $USAGE = <<EOF;
usage: $prog [-o file] [defines] -- file

Configures an Interchange program/script file with defaults.

options:

    -o file, --output=file    Name output file, default standard output

    Typical defines:

    LINK_PORT=7785   Set the tlink.c link port
	LINK_TIMEOUT=15  Set the tlink.c timeout

EOF

my $Output;
my $Force;

my %optctl = (

    'force'         => \$Force,
    'outputfile'    => \$Output,
	'<>'			=> sub {
							my $arg = shift;
							return unless $arg =~ /=/;
							my ($opt, $val) = split /=/, $arg, 2;
							die "Can't set \U$opt\E twice.\n$USAGE\n"
								if defined $Self->{$opt};
							$Self->{$opt} = $val;
							return;
							},
);

my @options = ( qw/

    outputfile|o=s
    force|f
    <>

/ );

GetOptions(\%optctl, @options)			or die "\n$USAGE\n";

DOIT: {
	local ($/);
	$_ = <>;
}

sub doit {
	my ($self, $orig, $template, $preamble, $key, $postamble) = @_;
	my $replace =  $Self->{$key} || $Config{$key};

	return "$orig$template" unless defined $replace;
	$preamble =~ s/~_~(\w+)~_~/$Self->{$1} || $Config{$1}/eg;
	$postamble =~ s/~_~(\w+)~_~/$Self->{$1} || $Config{$1}/eg;
	return "$preamble$replace$postamble$template";
}

if($Output) {
	if (-e $Output and ! $Force) {
		die "Output file $Output exists. Use -f option to overwrite.\n";
	}
	open(OUT, ">$Output") 
		or die "Cannot write output file $Output: $!\n";
	select OUT;
}

	s{(~@~(\w+)~@~)}{doit($Self, $1, '', '', $2, '')}eg;
	s{(.*)(\n[ 	]*#(.*)~_~(\w+)~_~(.*))}{doit($Self, $1, $2, $3, $4, $5)}eg;
	s{(.*)(\n[ 	]*/\*(.*)~_~(\w+)~_~(.*)\*/)}{doit($Self, $1, $2, $3, $4, $5)}eg;
	print;

=head1 NAME

config_prog -- Configure Interchange programs with MakeMaker variables

=head1 VERSION

# $Id: config_prog.PL,v 2.0.2.2 2002-11-26 03:21:13 jon Exp $

=head1 DESCRIPTION

No documentation planned.

=head1 SEE ALSO

compile_link(1), config_prog(1), configdump(1), dump(1), expire(1),
expireall(1), localize(1), makecat(1), interchange(1), offline(1),
restart(1), update(1)

=cut
_EoP_
	s{.*\n(#(.*)~_~(\w+)~_~(.*))}{$2 . doit($3) . "$4\n$1"}eg;
	my $file = $0;
	$file =~ s/\.PL$//;
	open(OUT, ">$file") 
		or die "Create $file: $!\n";
	print OUT $_;
}
