#!/usr/bin/perl
#
# $Id: Cart.pm,v 1.2 2000-07-12 03:08:10 heins Exp $
#
# Copyright (C) 1996-2000 Akopia, Inc. <info@akopia.com>
#
# This program was originally based on Vend 0.2
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
#
# Portions from Vend 0.3
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
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

$VERSION = substr(q$Revision: 1.2 $, 10);

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

# If the user has put in "0" for any quantity, delete that item
# from the order list.
sub toss_cart {
	my($s) = @_;
	my $i;
	my (@master);
    DELETE: for (;;) {
        foreach $i (0 .. $#$s) {
            if ($s->[$i]->{quantity} <= 0) {
				next if defined $s->[$i]->{mv_control} and
								$s->[$i]->{mv_control} =~ /\bnotoss\b/;
				push (@master, $s->[$i]->{mv_mi})
					if $s->[$i]->{mv_mi} && ! $s->[$i]->{mv_si};
                splice(@$s, $i, 1);
                next DELETE;
            }
        }
        last DELETE;
    }

	return 1 unless @master;
	my $mi;
	my %save;
	my @items;
	# Brute force delete for subitems of any deleted master items
	foreach $mi (@master) {
        foreach $i (0 .. $#$s) {
            $save{$i} = 1
				unless $s->[$i]->{mv_si} and $s->[$i]->{mv_mi} eq $mi;
        }
	}
	@items = @$s;
	@{$s} = @items[sort {$a <=> $b} keys %save];
    1;
}

sub get_cart {
	my($cart) = shift or return $Vend::Items;
	return $Vend::Items = $cart;
}

1;

__END__
