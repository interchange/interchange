UserTag available_www_shipping Order only
UserTag available_www_shipping Routine <<EOR
sub {
	my ($only) = @_;
	my $ups;
	my $fedex;
	my $other;
	if(! $only or $only =~ /ups/i) {
		eval {
			require Business::UPS;
		};
		$ups = $@ ? 0 : 1;
	}
	
	if(! $only or $only =~ /fed/i) {
		eval {
			require Business::Fedex;
		};
		$fedex = $@ ? 0 : 1;
	}
	my @ups_modes;
	my @fed_modes;
	if($ups) {
		push @ups_modes,
			'1DM' => {type => 'UPS', description => 'Next Day Air Early AM'},
			'1DML' => {type => 'UPS', description => 'Next Day Air Early AM Letter'},
			'1DA' => {type => 'UPS', description => 'Next Day Air'},
			'1DAL' => {type => 'UPS', description => 'Next Day Air Letter'},
			'1DP' => {type => 'UPS', description => 'Next Day Air Saver'},
			'1DPL' => {type => 'UPS', description => 'Next Day Air Saver Letter'},
			'2DM' => {type => 'UPS', description => '2nd Day Air A.M.'},
			'2DA' => {type => 'UPS', description => '2nd Day Air'},
			'2DML' => {type => 'UPS', description => '2nd Day Air A.M. Letter'},
			'2DAL' => {type => 'UPS', description => '2nd Day Air Letter'},
			'3DS' => {type => 'UPS', description => '3 Day Select'},
			'GNDCOM' => {type => 'UPS', description => 'Ground Commercial'},
			'GNDRES' => {type => 'UPS', description => 'Ground Residential'},
			'XPR' => {type => 'UPS', description => 'Worldwide Express'},
			'XDM' => {type => 'UPS', description => 'Worldwide Express Plus'},
			'XPRL' => {type => 'UPS', description => 'Worldwide Express Letter'},
			'XDML' => {type => 'UPS', description => 'Worldwide Express Plus Letter'},
			'XPD' => {type => 'UPS', description => 'Worldwide Expedited'},
		;
	}

	if($fedex) {
		push @fed_modes,
		'FEG' => {type => 'FED', description => 'FedEx Ground'},
		'FEH' => {type => 'FED', description => 'FedEx Home Delivery'},
		'FPO' => {type => 'FED', description => 'FedEx Priority Overnight'},
		'FSO' => {type => 'FED', description => 'FedEx Standard Overnight'},
		'F2D' => {type => 'FED', description => 'FedEx 2-Day'},
		'FES' => {type => 'FED', description => 'FedEx Express Saver'},
		'FIP' => {type => 'FED', description => 'FedEx International Priority'},
		'FIE' => {type => 'FED', description => 'FedEx International Economy'},
		;
	}
	if (wantarray) {
		return @ups_modes, @fed_modes;
	}
	else {
		my $out = '';
		my $i;
		for ($i = 0; $i < @ups_modes; $i += 2) {
			my $ref = $ups_modes[$i + 1];
			$out .= qq{UPSE:$ups_modes[$i]\t$ref->{type}: $ref->{description}\n};
		}
		for ($i = 0; $i < @fed_modes; $i += 2) {
			my $ref = $fed_modes[$i + 1];
			$out .= qq{FEDE:$fed_modes[$i]\t$ref->{type}: $ref->{description}\n};
		}
		return $out;
	}
}
EOR
