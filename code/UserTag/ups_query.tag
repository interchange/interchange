# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: ups_query.tag,v 1.12 2007-03-30 23:40:57 pajamian Exp $

UserTag  ups-query  Order    mode origin zip weight country
UserTag  ups-query  addAttr
UserTag  ups-query  Version  $Revision: 1.12 $
UserTag  ups-query  Routine  <<EOR
sub {
 	my( $mode, $origin, $zip, $weight, $country, $opt) = @_;
	$opt ||= {};
	BEGIN {
		eval {
			require Business::UPS;
			import Business::UPS;
		};
	};

	$origin		= $::Variable->{UPS_ORIGIN}
					if ! $origin;
	$country	= $::Values->{$::Variable->{UPS_COUNTRY_FIELD}}
					if ! $country;
	$zip		= $::Values->{$::Variable->{UPS_POSTCODE_FIELD}}
					if ! $zip;

	my $modulo = $opt->{aggregate};

	if($modulo and $modulo < 10) {
		$modulo = $::Variable->{UPS_QUERY_MODULO} || 150;
	}
	elsif(! $modulo) {
		$modulo = 9999999;
	}

	$country = uc $country;

    my %exception;

	$exception{UK} = 'GB';

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

#::logDebug("calling with: " . join("|", $mode, $origin, $zip, $weight, $country));
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
			%cline = (
				weight => $weight,
				origin => $origin,
				country => $country,
				zip	=> $zip,
				shipmode => $mode,
			);

			my @items;
			# reverse sort makes zip first
			for(reverse sort keys %cline) {
				push @items, "$_ = " . $db->quote($cline{$_}, $_);
			}

			my $string = join " AND ", @items;
			my $q = qq{SELECT code,cost,updated from $tname WHERE $string};
			my $ary = $db->query($q);
			if($ary and $ary->[0] and $cache_code = $ary->[0][0]) {
				$shipping = $ary->[0][1];
				$updated = $ary->[0][2];
				$now = time();
				if($now - $updated > 86000) {
					undef $shipping;
					$updated = $now;
				}
				elsif($shipping <= 0) {
					$error = $shipping;
					$shipping = 0;
				}
			}
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

			($maxcost, $zone, $error) = getUPS( $mode, $origin, $zip, $modulo, $country);
			if($error) {
				$Vend::Session->{ship_message} .= " $mode: $error";
				return 0;
			}
			$shipping += $maxcost;
		}

		undef $error;
		($tmpcost, $zone, $error) = getUPS( $mode, $origin, $zip, $w, $country);

		$shipping += $tmpcost;
		if($cache and $shipping) {
			$cline{updated} = $now || time();
			$cline{cost} = $shipping || $error;
			$db->set_slice($cache_code, \%cline);
		}
	}

	if($error) {
		$Vend::Session->{ship_message} .= " $mode: $error";
		return 0;
	}
	return $shipping;
}
EOR

UserTag  ups-query  Documentation <<EOD

=head1 NAME

ups-query tag -- calculate UPS costs via www

=head1 SYNOPSIS

  [ups-query
     weight=NNN
     origin=45056*
     zip=61821*
     country=US*
     mode=MODE
     aggregate=N*
  ]
	
=head1 DESCRIPTION

Calculates UPS costs via the WWW using Business::UPS.

Options:

=over 4

=item weight

Weight in pounds. (required)

=item mode

Any valid Business::UPS mode (required). Example: 1DA,2DA,GNDCOM

=item origin

Origin zip code. Default is $Variable->{UPS_ORIGIN}.

=item zip

Destination zip code. Default $Values->{zip}.

=item country

Destination country. Default $Values->{country}.

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

If set to a number above 10, will be the modulo to do repeated calls by. So:

	[ups-query weight=400 mode=GNDCOM aggregate=100]

is equivalent to:

	[calc]
		[ups-query weight=100 mode=GNDCOM] + 
		[ups-query weight=100 mode=GNDCOM] + 
		[ups-query weight=100 mode=GNDCOM] + 
		[ups-query weight=100 mode=GNDCOM];
	[/calc]

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

EOD
