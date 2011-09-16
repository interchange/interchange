# Vend::Ship::QueryUPS - Interchange shipping code
# 
# $Id: QueryUPS.pm,v 1.8 2008-05-14 16:21:02 mheins Exp $
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

package Vend::Ship::QueryUPS;

use Vend::Util;
use Vend::Interpolate;
use Vend::Data;
use Vend::Ship;
use POSIX qw(ceil);

my $Have_Business_UPS;
eval {
	require Business::UPS;
	import Business::UPS;
	$Have_Business_UPS = 1;
};

sub calculate {
	my ($mode, $weight, $row, $opt, $tagopt, $extra) = @_;

	unless($Have_Business_UPS) {
		do_error("Ship mode %s: Requires installation of Business::UPS", $mode);
	}

	$opt->{service}         ||= $opt->{table};
	if(! $opt->{service} and $extra =~ /^\w+$/)  {
		$opt->{service} = $extra;
	}
	$opt->{service} ||= $opt->{table} || $mode;

	$opt->{origin}			||= $::Variable->{UPS_ORIGIN};
	$opt->{country_field}	||= $::Variable->{UPS_COUNTRY_FIELD} || 'country';
	$opt->{geo}				||= $::Variable->{UPS_POSTCODE_FIELD} || 'zip';

	my $origin  = $opt->{origin};
	my $country = $opt->{country} || $::Values->{$opt->{country_field}};

	$country ||= $opt->{default_country} || 'US';

	my $zip     = $opt->{zip}	  || $::Values->{$opt->{geo}};
	$zip ||= $opt->{default_geo};

	my $modulo = $opt->{aggregate};

	if($modulo and $modulo <= 1) {
		$modulo = $::Variable->{UPS_QUERY_MODULO} || 150;
	}
	elsif(! $modulo) {
		$modulo = 9999999;
	}

	$country = uc $country;

    my %exception = ( UK => 'GB');

	if(! $::Variable->{UPS_COUNTRY_REMAP} ) {
		# do nothing
	}
	elsif ($::Variable->{UPS_COUNTRY_REMAP} =~ /=/) {
		my $new = Vend::Util::get_option_hash($::Variable->{UPS_COUNTRY_REMAP});
		Vend::Util::get_option_hash(\%exception, $new);
	}
	else {
		Vend::Util::hash_string($::Variable->{UPS_COUNTRY_REMAP}, \%exception);
	}

	$country = $exception{$country} if $exception{$country};

	# In the U.S., UPS only wants the 5-digit base ZIP code, not ZIP+4
	$country eq 'US' and $zip =~ /^(\d{5})/ and $zip = $1;

#::logDebug("calling QueryUPS with: " . join("|", $opt->{service}, $origin, $zip, $weight, $country,$modulo));

	my $cache;
	my $cache_code;
	my $db;
	my $now;
	my $updated;
	my %cline;
	my $shipping;
	my $zone;
	my $error;

	my $ctable = $opt->{cache_table} || 'ups_cache';


	if($Vend::Database{$ctable}) {
		$Vend::WriteDatabase{$ctable} = 1;
		CACHE: {
			$db = dbref($ctable)
				or last CACHE;
			my $tname = $db->name();
			$cache = 1;
			$weight = ceil($weight);
			%cline = (
				weight => $weight,
				origin => $origin,
				country => $country,
				zip	=> $zip,
				shipmode => $opt->{service},
			);

			my @items;
			# reverse sort makes zip first
			for(reverse sort keys %cline) {
				push @items, "$_ = " . $db->quote($cline{$_}, $_);
			}

			my $string = join " AND ", @items;
			my $q = qq{SELECT code,cost,updated from $tname WHERE $string};
			my $ary = $db->query($q);
#::logDebug("query cache: " . ::uneval($ary));
			if($ary and $ary->[0] and $cache_code = $ary->[0][0]) {
				$shipping = $ary->[0][1];
				$updated = $ary->[0][2];
				$now = time();
				if($now - $updated > $Variable->{UPS_CACHE_EXPIRE} || 86000) {
					undef $shipping;
					$updated = $now;
				}
				elsif($shipping <= 0) {
					$error = $shipping;
					$updated = $now;
					$shipping = 0;
				}
			}
#::logDebug("shipping is: " . (defined $shipping ? $shipping : 'undef'));
		}
	}

	my $w = $weight;
	my $maxcost;
	my $tmpcost;

	unless(defined $shipping) {
		$shipping = 0;
		while($w > $modulo) {
			$w -= $modulo;
			if($maxcost) {
				$shipping += $maxcost;
				next;
			}

			($maxcost, $zone, $error)
				= getUPS( $opt->{service}, $origin, $zip, $modulo, $country);
			if($error) {
				do_error(	"Ship mode %s: Error calling UPS service %s",
							$mode,
							$opt->{service}, );
				return 0;
			}
			$shipping += $maxcost;
		}

		undef $error;
#::logDebug("calling getUPS( $opt->{service}, $origin, $zip, $w, $country)");
		($tmpcost, $zone, $error)
			= getUPS( $opt->{service}, $origin, $zip, $w, $country);

		$shipping += $tmpcost;
		if($cache) {
			$cline{updated} = $now || time();
			$cline{cost} = $shipping || $error;
			$db->set_slice($cache_code, \%cline);
		}
	}

	if($error) {
		do_error(	"Ship mode %s: Error calling UPS service %s",
					$mode,
					$opt->{service}, );
		$shipping = 0;
	}
	return $shipping;
}

=head1 NAME

Vend::Ship::QueryUPS -- calculate UPS costs via www

=head1 SYNOPSIS

  (catalog.cfg)

  Shipping  QueryUPS  default_geo  45056

  (shipping.asc)
  ground: UPS Ground Commercial
     origin  45056
     service GNDCOM

	 min	0
	 max	0
	 cost	e Nothing to ship!

	 min	0
	 max	150
	 cost	s QueryUPS

	 min	150
	 max	99999999
	 cost	e Too heavy for UPS.

=head1 DESCRIPTION

Calculates UPS costs via the WWW using Business::UPS. 

To activate, configure any parameter in catalog.cfg. A good choice
is the default origin zip.

Options:

=over 4

=item weight

Weight in pounds. Required -- normally passed via CRIT parameter.

=item service

Any valid Business::UPS mode (required). Example: 1DA,2DA,GNDCOM. Defaults
to the mode name.

=item geo

Location of field containing zip code. Default is 'zip'.

=item country_field

Location of field containing country code. Default is 'country'.

=item default_geo

The ZIP code to use if none supplied -- for defaulting shipping to some
value in absence of ZIP. No default -- will return 0 and error if
no zip.

=item default_country

The country code to use if none supplied -- for defaulting shipping to some
value in absence of country. Default US.

=item aggregate

If 1, aggregates by a call to weight=150 (or $Variable->{UPS_QUERY_MODULO}).
Multiplies that times number necessary, then runs a call for the
remainder. In other words:

	[ups-query weight=400 mode=GNDCOM aggregate=1]

is equivalent to:

	[calc]
		[ups-query weight=150 mode=GNDCOM] + 
		[ups-query weight=150 mode=GNDCOM] + 
		[ups-query weight=100 mode=GNDCOM];
	[/calc]

If set to a number above 1, will be the modulo to do repeated calls by. So:

	[ups-query weight=400 mode=GNDCOM aggregate=100]

is equivalent to:

	[calc]
		[ups-query weight=100 mode=GNDCOM] + 
		[ups-query weight=100 mode=GNDCOM] + 
		[ups-query weight=100 mode=GNDCOM] + 
		[ups-query weight=100 mode=GNDCOM];
	[/calc]

To aggregate by 1, use .999999.

=item cache_table

Set to the name of a table (default ups_cache) which can cache the
calls so repeated calls for the same values will not require repeated
calls to UPS.

Table needs to be set up with:

	Database   ups_cache        ship/ups_cache.txt         __SQLDSN__
	Database   ups_cache        AUTO_SEQUENCE  ups_cache_seq
	Database   ups_cache        DEFAULT_TYPE varchar(12)
	Database   ups_cache        INDEX  weight origin zip shipmode country

And have the fields:

	 code weight origin zip country shipmode cost updated

Typical cached data will be like:

	code	weight	origin	zip	country	shipmode	cost	updated
	14	11	45056	99501	US	2DA	35.14	1052704130
	15	11	45056	99501	US	1DA	57.78	1052704130
	16	11	45056	99501	US	2DA	35.14	1052704132
	17	11	45056	99501	US	1DA	57.78	1052704133

Cache expires in one day.

=back

=cut

1;
