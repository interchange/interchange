# Vend::Cart - Interchange shopping cart management routines
#
# $Id: Cart.pm,v 1.2.4.1 2003-01-25 22:21:27 racke Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. <interchange@redhat.com>
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

$VERSION = substr(q$Revision: 1.2.4.1 $, 10);

use strict;

sub TIESCALAR {
	my $class = shift;
	my $instance = shift || undef;
	$Vend::CurrentCart = 'main';
	$::Levies = $Vend::Session->{levies}{main} ||= [];
	return bless \$instance => $class;
}

sub FETCH {
	my $cartname = $Vend::CurrentCart;
	$::Levies = $Vend::Session->{levies}{$cartname} ||= [];
	return scalar ($::Carts->{$cartname} ||= []);
}

sub STORE {
	my ($self, $cart) = @_;
	my $name;
	if( ref($cart) eq 'ARRAY' ) {
		for(keys %$::Carts) {
#::logDebug("checking name $_ via ref comparison");
			$name = $_ if $::Carts->{$_} eq $cart;
		}

		if (! $name) {
			$name = $cart->[0]{mv_cartname} if $cart->[0]{mv_cartname};
		}

		if (! $name) {
			for my $pname (keys %$::Carts) {
#::logDebug("checking name $pname via line comparison");
				my $pros = $::Carts->{$pname};
				next if ref($pros) ne 'ARRAY';
				next if @$pros != @$cart;
				CHECKLINES: {
					for( my $i = 0; $i < @$pros; $i++ ) {
						my $p = $pros->[$i];
						my $c = $cart->[$i];
						my @k1 = keys %$p;
						my @k2 = keys %$c;
						last CHECKLINES if @k1 != @k2;
						foreach my $k (@k1) {
							last CHECKLINES
								unless exists $c->{$k};
							last CHECKLINES
								unless $c->{$k} eq $p->{$k};
						}
					}
#::logDebug("found name $pname via line comparison");
					$name = $pname;
				}
				last if $name;
			}
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
	$::Levies = $Vend::Session->{levies}{$Vend::CurrentCart} ||= [];
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
	my($s, $cartname) = @_;
	my $i;
	my $sub;
	my (@master);
	my (@cascade);
	DELETE: for (;;) {
		foreach $i (0 .. $#$s) {
			my $item = $s->[$i];
			if ($sub = $Vend::Cfg->{ItemAction}{$s->[$i]{code}}) {
				$sub->($item);
			}
			if ($item->{quantity} <= 0) {
				next if defined $item->{mv_control} and
								$item->{mv_control} =~ /\bnotoss\b/;
				if ($item->{mv_mi} && ! $item->{mv_si}) {
					push (@master, $item->{mv_mi});
				}
				elsif ( $item->{mv_ci} ) {
					push (@master, $item->{mv_ci});
				}
				splice(@$s, $i, 1);
				next DELETE;
			}

			if($Vend::Cfg->{MinQuantityField}) {
				if(! defined $item->{mv_min_quantity}) {
					my ($tab, $col) = split /:+/, $Vend::Cfg->{MinQuantityField};
					if(! length $col) {
						$col = $tab;
						$tab = $item->{mv_ib} || $Vend::Cfg->{ProductFiles}[0];
					}
					$item->{mv_min_quantity} = ::tag_data($tab, $col, $item->{code})
											 || '';
				}

				if(
					length $item->{mv_min_quantity}
					and 
					$item->{quantity} < $item->{mv_min_quantity}
					)
				{
					$item->{quantity} = $item->{mv_min_quantity};
					$item->{mv_min_under} = 1;
				}
			}

			if($Vend::Cfg->{MaxQuantityField}) {
				my ($tab, $col) = split /:+/, $Vend::Cfg->{MaxQuantityField};
				if(! length $col) {
					$col = $tab;
					$tab = $item->{mv_ib} || $Vend::Cfg->{ProductFiles}[0];
				}
				$item->{mv_max_quantity} = ::tag_data($tab, $col, $item->{code})
											 || '';

				if(
					length $item->{mv_max_quantity}
					and 
					$item->{quantity} > $item->{mv_max_quantity}
					)
				{
					$item->{quantity} = $item->{mv_max_quantity};
					$item->{mv_max_over} = 1;
				}
			}

			next unless $Vend::Cfg->{Limit}{cart_quantity_per_line};
			
			$item->{quantity} = $Vend::Cfg->{Limit}{cart_quantity_per_line}
				if
					$item->{quantity}
						>
					$Vend::Cfg->{Limit}{cart_quantity_per_line};
		}
		last DELETE;
	}

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
	Vend::Interpolate::levies(1, $cartname);
	return 1;
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
