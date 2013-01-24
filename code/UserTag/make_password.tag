# Copyright 2003-2013 Jon Jensen <jon@endpoint.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version. See the LICENSE file for details.

Usertag make-password Routine <<EOR
sub {
	my @v = qw( a e i o u );
	my @c = qw( b d f g h j k m n p r s t v w z );  # no l, y
	my @c2 = (@c, qw( c q x ));
	my @d = (2..9);   # no 0, 1

	my $did_numbers = 0;
	my $did_letters = 0;
	my $last_numbers;
	my $pass = '';
	for (1..3) {
		my $l = rand(10) > 7;
		if ($last_numbers) {
			$l = 1;
		}
		elsif ($_ > 2) {
			undef $l if ! $did_numbers;
			$l = 1 if ! $did_letters;
		}
		if ($l) {
			$pass .= $c[rand @c] . $v[rand @v];
			$pass .= $c2[rand @c2] if rand(10) > 5;
			++$did_letters;
			undef $last_numbers;
		}
		else {
			$pass .= $d[rand @d];
			$pass .= $d[rand @d] if rand(10) > 3;
			++$did_numbers;
			$last_numbers = 1;
		}
		redo if $_ > 2 and length($pass) < 8;
	}
	return $pass;
}
EOR
