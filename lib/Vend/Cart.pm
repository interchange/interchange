# Vend::Cart - Interchange shopping cart management routines
#
# $Id: Cart.pm,v 2.1.2.3 2002-11-26 03:21:09 jon Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. and
# Interchange Development Group, http://www.icdevgroup.org/
#
# This program was originally based on Vend 0.2 and 0.3
# Copyright 1995 by Andrew M. Wilcox <amw@wilcoxsolutions.com>
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

package Vend::Cart;

$VERSION = substr(q$Revision: 2.1.2.3 $, 10);

use strict;

sub TIESCALAR {
	my $class = shift;
	my $instance = shift || undef;
	return bless \$instance => $class;
}

sub FETCH {
	return scalar ($::Carts->{$Vend::CurrentCart || 'main'} ||= []);
}

sub STORE {
	my ($self, $cart) = @_;
	my $name;
	if(ref $cart) {
		for(keys %$::Carts) {
			$name = $_ if $::Carts->{$_} eq $cart;
		}
		if (! $name) {
			$name = 'UNKNOWN';
			$::Carts->{UNKNOWN} = $cart;
		}
		$Vend::CurrentCart = $name;
	}
	else {
		$Vend::CurrentCart = $cart;
	}
	return $::Carts->{$Vend::CurrentCart};
}

sub DESTROY { }


# BEGTEST

=head2 Test header for item toss

 my $cart = [
	{
		code => 1,
		mv_mi => 1,
		mv_si => 0,
		mv_ci => 0,
		quantity => 0,
	},
	{
		code => 2,
		mv_mi => 1,
		mv_si => 1,
		mv_ci => 2,
		quantity => 1,
	},
	{
		code => 3,
		mv_mi => 2,
		mv_si => 1,
		mv_ci => 0,
		quantity => 1,
	},
	{
		code => 5,
		mv_mi => 1,
		mv_si => 1,
		mv_ci => 3,
		quantity => 1,
	},
	{
		code => 50,
		mv_mi => 3,
		mv_si => 1,
		mv_ci => 0,
		quantity => 1,
	},
	{
		code => 51,
		mv_mi => 3,
		mv_si => 1,
		mv_ci => 31,
		quantity => 1,
	},
	{
		code => 52,
		mv_mi => 31,
		mv_si => 1,
		mv_ci => 0,
		quantity => 1,
	},
	{
		code => 6,
		mv_mi => 1,
		mv_si => 1,
		mv_ci => 0,
		quantity => 1,
	},
	{
		code => 7,
		mv_mi => 0,
		mv_si => 0,
		mv_ci => 0,
		quantity => 1,
	},
];

=cut

# If the user has put in "0" for any quantity, delete that item
# from the order list.
sub toss_cart {
	my($s) = @_;
	my $i;
	my $sub;
	my (@master);
	my (@cascade);
	DELETE: for (;;) {
		foreach $i (0 .. $#$s) {
			if ($sub = $Vend::Cfg->{ItemAction}{$s->[$i]{code}}) {
				$sub->($s->[$i]);
			}
			if ($s->[$i]->{quantity} <= 0) {
				next if defined $s->[$i]->{mv_control} and
								$s->[$i]->{mv_control} =~ /\bnotoss\b/;
				if ($s->[$i]->{mv_mi} && ! $s->[$i]->{mv_si}) {
					push (@master, $s->[$i]->{mv_mi});
				}
				elsif ( $s->[$i]->{mv_ci} ) {
					push (@master, $s->[$i]->{mv_ci});
				}
				splice(@$s, $i, 1);
				next DELETE;
			}
			next unless $Vend::Cfg->{Limit}{cart_quantity_per_line};
			
			$s->[$i]->{quantity} = $Vend::Cfg->{Limit}{cart_quantity_per_line}
				if
					$s->[$i]->{quantity}
						>
					$Vend::Cfg->{Limit}{cart_quantity_per_line};
		}
		last DELETE;
	}

	return 1 unless @master;
	my $mi;
	my %save;
	my @items;

	# Brute force delete for subitems of any deleted master items
	while (@master) {
		@cascade = @master;
		@master = ();
		foreach $mi (@cascade) {
			%save = ();
			foreach $i (0 .. $#$s) {
				if ( $s->[$i]->{mv_si} and $s->[$i]->{mv_mi} eq $mi ) {
					delete $save{$i};
# print "mi=$mi == $s->[$i]->{mv_mi}, si=$s->[$i]->{mv_si}, ci=$s->[$i]->{mv_ci}\n";
					push(@master, $s->[$i]->{mv_ci})
						if $s->[$i]->{mv_ci};
				}
				else {
# print "mi=$mi != $s->[$i]->{mv_mi}, si=$s->[$i]->{mv_si}\n";
					$save{$i} = 1;
				}
			}
			@items = @$s;
			@{$s} = @items[sort {$a <=> $b} keys %save];
		}
	}
	1;
}

=head2 Test footer for item toss

	toss_cart($cart);

	use Data::Dumper;
	$Data::Dumper::Indent = 2;
	$Data::Dumper::Terse = 2;
	print Data::Dumper::Dumper($cart);

	# ENDTEST

=cut

1;

__END__
