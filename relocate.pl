#!/usr/bin/perl -w

# relocate.pl
#
# Rewrite pathnames or other values that need to be hardcoded in
# files. Take a commented line, remove the leading hash character,
# substitute for the variable inside ~_~HERE~_~, and place the
# result on the line above the comment, like this:

=for example

use lib '/home/jon/interchange/lib';
#use lib '~_~INSTALLPRIVLIB~_~';

=cut

# A single output filename can be specified on the command line, and
# the input filename will be the same, with a .PL extension added.
# If no filename is given, just filter from stdin to stdout.

use strict;

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

no warnings 'void';

DOIT: {
	my ($input, $output);
	$output = $ARGV[0];
	$input = "$output.PL" if $output;

	local ($/);
	@ARGV = ($input) if $input;
	local ($_) = <>;

	s{.*\n(#(.*)~_~(\w+)~_~(.*))}{$2 . doit($3) . "$4\n$1"}eg;

	if ($output) {
		open STDOUT, ">$output" or die "Error creating $output: $!\n";
	}
	print;
	close STDOUT;
}
