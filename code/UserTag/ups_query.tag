UserTag  ups-query  Order  mode origin zip weight country
UserTag  ups-query  Routine <<EOR
sub {
 	my( $mode, $origin, $zip, $weight, $country) = @_;
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

	$country = uc $country;

	# In the U.S., UPS only wants the 5-digit base ZIP code, not ZIP+4
	$country eq 'US' and $zip =~ /^(\d{5})/ and $zip = $1;

#::logGlobal("calling with: " . join("|", $mode, $origin, $zip, $weight, $country));
	my ($shipping, $zone, $error) =
		getUPS( $mode, $origin, $zip, $weight, $country);
#::logGlobal("received back: " . join("|", $shipping, $zone, $error));

	if($error) {
		$Vend::Session->{ship_message} .= " $mode: $error";
		return 0;
	}
	return $shipping;
}
EOR

