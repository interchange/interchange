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
# expireall - Expire all interchange catalogs
#

use lib '/usr/local/interchange/lib';
#use lib '~_~INSTALLPRIVLIB~_~';
use lib '/usr/local/interchange';
#use lib '~_~INSTALLARCHLIB~_~';

use Getopt::Std;

## END CONFIGURABLE VARIABLES

BEGIN {

$Global::VendRoot = $Global::VendRoot || '/usr/local/interchange';
#$Global::VendRoot = $Global::VendRoot || '~_~INSTALLARCHLIB~_~';

    ($Global::VendRoot = $ENV{MINIVEND_ROOT})
        if defined $ENV{MINIVEND_ROOT};

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

my $query;

$USAGE = <<EOF;
Expire all listed Interchange catalogs. Will read information from
either the file passed with -f or:

	$Global::VendRoot/interchange.cfg

usage: expireall [-r] [-f file]

	-f    Alternate interchange.cfg file
	-r    Use reorganize parameter in command

EOF

use vars qw/$opt_e $opt_f $opt_n $opt_r/; 
getopts('e:f:rn') or die "$@\n$USAGE\n";

my $Configfile = $opt_f || $Global::ConfigFile;

my $flag = '';

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
	my $file;
	my @cfglines;

	open(MVCFG, "< $Configfile") or die "Couldn't read $Configfile: $!\n";
	while(<MVCFG>) { push(@cfglines, $_) if /^\s*catalog\s+/i }
	close MVCFG;

	my %seen;
	@cfglines = grep !$seen{$_}++, @cfglines;

	for(@cfglines) {
		next unless /^\s*(?:sub)?catalog\s+([-\w_]+)/i;
		push @cats, $1;
	}

}

for(@cats) {
	system "$Global::VendRoot/bin/expire $flag -c $_";
}

=head1 NAME

expireall -- Run Interchange expire on all catalogs

=head1 VERSION

$Id: expireall.PL,v 1.7 2000-09-25 15:47:45 heins Exp $

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
