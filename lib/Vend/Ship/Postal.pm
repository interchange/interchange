# Vend::Ship::Postal - Interchange shipping code
# 
# $Id: Postal.pm,v 1.8 2007-08-09 13:40:56 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

package Vend::Ship::Postal;

use Vend::Util;
use Vend::Interpolate;
use Vend::Data;
use Vend::Ship;

sub calculate {
	my ($mode, $weight, $row, $opt, $tagopt, $extra) = @_;

	$opt ||= { auto => 1 };

#::logDebug("Postal custom: mode=$mode weight=$weight row=$row opt=" . uneval($opt));

	$type = $opt->{table};
	$o->{geo} ||= 'country';

	if(! $type) {
		$extra = interpolate_html($extra) if $extra =~ /__|\[/;;
		($type) = split /\s+/, $extra;
	}

	unless($type) {
		do_error("No table/type specified for %s shipping", 'Postal');
		return 0;
	}

	$country = $::Values->{$o->{geo}};

	if($opt->{packaging_weight}) {
		$weight += $opt->{packaging_weight};
	}
#::logDebug("ready to calculate postal type=$type country=$country weight=$weight");

	if($opt->{source_grams}) {
		$weight *= 0.00220462;
	}
	elsif($opt->{source_kg}) {
		$weight *= 2.20462;
	}
	elsif($opt->{source_oz}) {
		$weight /= 16;
	}

	if($opt->{auto}) {
		if($type eq 'surf_lp') {
			$opt->{oz} = 1;
		}
		elsif ($type eq 'air_lp') {
			$opt->{oz} = 1;
		}

		if($type =~ /_([pl]p)$/) {
			$opt->{max_field} = "max_$1";
		}
		elsif ($type =~ /^(ems|gxg)$/) {
			$opt->{max_field} = "max_$1";
		}
	}

	if($opt->{oz}) {
		$weight *= 16;
	}

	$weight = POSIX::ceil($weight);

	$opt->{min_weight} ||= 1;

	$weight = $opt->{min_weight} if $opt->{min_weight} > $weight;

	if(my $modulo = $opt->{aggregate}) {
		if($weight > $modulo) {
			my $cost = 0;
			my $w = $weight;
			while($w > $modulo) {
				$w -= $modulo;
				$cost += calculate($type, $modulo, $country, $opt);
			}
			$cost += calculate($type, $w, $country, $opt);
			return $cost;
		}
	}

	$opt->{table} ||= $type;
	$opt->{zone_table} ||= 'usps';

	unless (defined $Vend::Database{$opt->{zone_table}}) {
		logError("Postal lookup called, no database table named '%s'", $opt->{zone_table});
		return undef;
	}

	unless (defined $Vend::Database{$opt->{table}}) {
		logError("Postal lookup called, no database table named '%s'", $opt->{table});
		return undef;
	}

	$country =~ s/\W+//;
	$country = uc $country;

	unless(length($country) == 2) {
		return do_error(
						'Country code %s improper format for postal shipping.',
						$country,
						);
	}


	my $crecord = tag_data($opt->{zone_table}, undef, $country, {hash => 1})
					or return do_error(
							'Country code %s has no zone for postal shipping.',
							$country,
						);

	$opt->{type_field} ||= $type;

	my $zone = $crecord->{$opt->{type_field}};

	unless($zone =~ /^\w+$/) {
		return do_error(
						'Country code %s has no zone for type %s.',
						$country,
						$type,
					);
	}

	$zone = "zone$zone" unless $zone =~ /^zone/ or $opt->{verbatim_zone};
	
	my $maxits = $opt->{max_modulo} || 4;
	my $its = 1;
	my $cost;

	do {
		$cost = tag_data($opt->{table}, $zone, $weight);
		$weight++;
	} until $cost or $its++ > $maxits;
		
	return do_error(
					"Zero cost returned for mode %s, geo code %s.",
					$type,
					$country,
				)
		unless $cost;

	return $cost;
}

=head1 NAME

Vend::Ship::Postal -- Calculate US Postal service international rates

=head1 SYNOPSIS

 (in catalog.cfg)

    Database   usps             ship/usps.txt              TAB
    Database   air_pp           ship/air_pp.txt            TAB
    Database   surf_pp          ship/surf_pp.txt           TAB

 (in shipping.asc)

    air_pp: US Postal Air Parcel
        crit            weight
        min             0
        max             0
        cost            e No shipping needed!
        at_least        4
        adder           1
        aggregate       70
        table           air_pp

        min             0
        max             1000
        cost            s Postal

        min             70
        max             9999999
        cost            e Too heavy for Air Parcel

    surf_pp:    US Postal Surface Parcel
        crit            weight
        min             0
        max             0
        cost            e No shipping needed!
        at_least        4
        adder           1
        aggregate       70
        table           surf_pp

        min             0
        max             1000
        cost            s Postal

        min             70
        max             9999999
        cost            e Too heavy for Postal Parcel

=head1 DESCRIPTION

Looks up a service zone by country in the C<usps> table, then looks in
the appropriate rate table for a price by that zone.

Can aggregate shipments greater than 70 pounds by assuming you will ship
multiple 70-pound packages (plus one package with the remainder).

=cut

1;
