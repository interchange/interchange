#!/usr/bin/perl

package mvhints;

sub get_hints {
	my @out;

	my $condition;
	my $routine;

	$condition = sub { $^O =~ /nolongernecessary/i };
	$routine = sub {
		my $fn = 'interchange.cfg.dist';
		rename $fn, "$fn.bak";
		open HINTIN, "$fn.bak"
			or die "cannot open $fn.bak: $!\n";
		open HINTOUT, ">$fn"
			or die "cannot write $fn: $!\n";
		while(<HINTIN>) {
			s/
				^\s*Housekeeping\s+\d+.*$
			/# Changed for $^O, no safe signals\nHousekeeping 1/xig;
			s/
				^\s*MaxServers\s+\d+.*$
			/# Changed for $^O, no safe signals\nMaxServers 0/xig;
			print HINTOUT $_;
		}
		close HINTIN;
		close HINTOUT;
		unlink "$fn.bak";
		return 1;
	};
	push @out, [ $condition, $routine ];

	$condition = sub { $Global::TryingThreads && $^O =~ /linux/i };
	$routine = sub {
		my $fn = 'interchange.cfg.dist';
		rename $fn, "$fn.bak";
		open HINTIN, "$fn.bak"
			or die "cannot open $fn.bak: $!\n";
		open HINTOUT, ">$fn"
			or die "cannot write $fn: $!\n";
		while(<HINTIN>) {
			print HINTOUT $_;
		}
		print HINTOUT <<EOF;

## Added because threaded Perl on linux has broken getppid() as
## of this distribution
Variable MV_GETPPID_BROKEN 1
EOF
		close HINTIN;
		close HINTOUT;
		unlink "$fn.bak";
		return 1;
	};
	push @out, [ $condition, $routine ];

	return @out;
}

1;
