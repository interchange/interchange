UserTag  fedex-query  Order  mode weight
UserTag  fedex-query  attrAlias origin_zip origin
UserTag  fedex-query  addAttr
UserTag  fedex-query  Documentation <<EOD


Required Variables
Construct a Rate request using the URL, variables, and values shown
below. If a value is not predetermined, the maximum length is shown in
parenthesis: 

http://grd.fedex.com/cgi-bin/rrr2010.exe 

 Variable Name
                          Value
 ?func
                        =
                          Rate
 Screen = Ground or HomeD
 OriginZip = U.S. or Canada origin postal code.
 OriginCountryCode = Origin country code: 

                                US for United States 
                                CA for Canada
 DestZip = U.S., Canada, or Mexico destination postal
                          code.
 DestCountryCode = Destination country code: 

                                US for United States 
                                CA for Canada 
                                MX for Mexico
 Weight = Weight, in pounds or kilograms, rounded to
                          the nearest whole number.
 WeightUnit = The Unit of measure for the given weight: 

                                KGS for kilograms 
                                LBS for pounds (The default value is
                                Lbs) 
 Length = Optional: Length, in inches or centimeters,
                          rounded to the nearest whole number. To
                          calculate dimensional weight, values must be
                          entered for length, width, and height.
 Width = Optional: Width, in inches or centimeters,
                          rounded to the nearest whole number. To
                          calculate dimensional weight, values must be
                          entered for length, width, and height.
 Height = Optional: Height, in inches or centimeters,
                          rounded to the nearest whole number. To
                          calculate dimensional weight, values must be
                          entered for length, width, and height.
 DimUnit = Optional: The Unit of measure for the given
                          dimensions (Length, Width, Height): 

                                IN for Inches (The default value is IN) 
                                CM for centimeters 
 AccessReturn = Optional: The number of accessorials
                          included in the request, plus the accessorial
                          description(s), plus =1, except for the
                          declared value accessorial, where the 1 is
                          replaced by the amount. Use a semicolon to
                          separate the number of accessorials included
                          from the first desciption, and a semicolon to
                          separate accessorials. The following are valid
                          accessorial values (values are
                          case-sensitive):

                          U.S. to U.S. 

                                USCOD: C.O.D.or E.C.O.D. collection 
                                USCT: Call tag 
                                USECT: Electronic call tag 
                                USAOD: Acknowledgement of delivery 
                                USHazMat: Hazardous material 
                                USDecVal: Declared value, each
                                additional $100 
                                USRS: Residential surcharge 
                                USANAC: Not in appropriate container
                                or single dimension greater than 60
                                inches 
                                USAPOD: Auto proof of delivery 

                          U.S. to Canada 

                                USCODC: C.O.D. collection to Canada 
                                USAOD: Acknowlegement of delivery 
                                USDecVal: Declared value, each
                                additional $100 
                                USANAC: Not in appropriate container
                                or single dimension greater than 60
                                inches 
                                USRS: Residential surcharge 
                                USAPOD: Auto proof of delivery 

                          U.S. to Mexico 

                                USDecVal: Declared value, each
                                additional $100 
                                USRS: Residential surcharge 
                                USANAC: Not in appropriate container
                                or single dimension greater than 60
                                inches 

                          Canada to Canada 

                                CACOD: C.O.D. or E.C.O.D. collection 
                                CACT: Call tag 
                                CAAOD: Acknowlegement of delivery 
                                CADecVal: Declared value, each
                                additional $100 
                                CARS: Residential surcharge 
                                CAANAC: Not in appropriate container
                                or single dimension greater than 60
                                inches 
                                CAAPOD: Auto proof of delivery 

                          Canada to U.S. 

                                CACOD: C.O.D. collection 
                                CADecVal: Declared value, each
                                additional $100 
                                CAANAC: Not in appropriate container
                                or single dimension greater than 60
                                inches 
                                CAAPOD: Auto proof of delivery 

                          U.S. to U.S. - Home Delivery 

                                USFHDAC: Address Correction 
                                USFHDANAC: Not in Approp. Container
                                or Single Dim. > 60 in. 
                                USFHDAOD: Acknowledgement of
                                Delivery 
                                USFHDDV: Declared Value Each
                                Additional $100 
                                USFHDGAD: FedEx Appointment Home
                                Delivery 
                                USFHDGADAPOD: FedEx Appointment
                                Home Delivery and Auto POD 
                                USFHDGED: FedEx Evening Home
                                Delivery 
                                USFHDGEDS: FedEx Evening Home
                                Delivery with Signature 
                                USFHDGEDSAP: FedEx Evening Home
                                Delivery with Signature and Auto POD 
                                USFHDGSDD: FedEx Date Certain
                                Home Delivery 
                                USFHDGSDDS: FedEx Date Certain
                                Day Home Delivery with Signature 
                                USFHDGSDDSAP: FedEx Date Certain
                                Day Home Delivery with Signature and
                                Auto POD 
                                USFHDGSS: FedEx Signature Home
                                Service 
                                USFHDGSSAPOD: FedEx Signature
                                Home Service and Auto POD 

Top 

Example
A URL for a Rate request without dimensional weight, oversize, or
accessorials would be constructed as follows: 

!!! Line breaks are used here for clarity; URLs cannot include line breaks or
spaces. 

http://grd.fedex.com/cgi-bin/rrr2010.exe
?func=Rate
&Screen=Ground
&OriginZip=44429
&OriginCountryCode=US
&DestZip=C1C1C1
&DestCountryCode=CA
&Weight=50

The URL for a Rate request that includes dimensions, oversize indicator,
and accessorials would be as follows: 

http://grd.fedex.com/cgi-bin/rrr2010.exe
?func=Rate
&Screen=Ground
&OriginZip=C1C1C1
&OriginCountryCode=CA
&DestZip=44429
&DestCountryCode=US
&Weight=50
&WeightUnit=KGS
&Length=36
&Width=36
&Height=30
&DimUnit=CM
&AccessReturn=2;USCODC=1;USDecVal=500

EOD
UserTag  fedex-query  Routine <<EOR
my $can_do_ground;
my $can_do_express;
sub {
 	my( $mode, $weight, $opt) = @_;
	BEGIN {
		eval {
			require LWP::Simple;
			$can_do_ground = 1;
		};
	};
	BEGIN {
		eval {
			require Business::Fedex;
			$can_do_express = 1;
		};
	};
	my $die = sub {
		my ($msg, @args) = @_;
		$msg = ::errmsg($msg, @args);
		$Vend::Session->{ship_message} .= " $msg";
		return 0;
	};

	my $fed;

	$opt->{target_url} ||= 'http://grd.fedex.com/cgi-bin/rrr2010.exe';
	$opt->{origin_country} ||= $::Variable->{COUNTRY} || 'US';
	$opt->{origin} ||= $::Variable->{UPS_ORIGIN};
	$opt->{zip} ||= $::Values->{$::Variable->{UPS_POSTCODE_FIELD}};
	$opt->{country} ||= $::Values->{$::Variable->{UPS_COUNTRY_FIELD}};
	$opt->{country} = uc $opt->{country};

	if($can_do_express and (! $opt->{cache} || ! $Vend::fedex_object) ) {
		eval {
			$Vend::fedex_object = new Business::Fedex (
				orig_country => $opt->{origin_country},
				orig_zip =>	$opt->{origin},
				weight => $opt->{weight},
				dest_country => $opt->{country},
				dest_zip => $opt->{zip},
				packaging => $opt->{packaging} || 'My Packaging',
			);
			$Vend::fedex_object->getrate;
		};
		# if there's a problem here with express lookups, log the error
		# but don't actually return so ground lookups can still be done 
		$die->($@) if $@;
	}
	$fed = $Vend::fedex_object if $can_do_express;

	my %is_express = (
		'FPO' => 1,
		'FSO' => 1,
		'F2D' => 1,
		'FES' => 1,
		'FIE' => 1,
		'FIP' => 1,
	);
	my %fe_map = (
    'FedEx Ground'                 => 'FEG',
    'FedEx Home Delivery'          => 'FEH',
    'FedEx Priority Overnight'     => 'FPO',
    'FedEx Standard Overnight'     => 'FSO',
    'FedEx 2-Day'                  => 'F2D',
    'FedEx Express Saver'          => 'FES',
    'FedEx International Priority' => 'FIP',
    'FedEx International Economy'  => 'FIE',
	);
	@fe_map{values %fe_map} = @fe_map{keys %fe_map};
#Debug("fed=" . ::uneval($fed));
	my @services;
#Debug("can_ground=$can_do_ground country=$opt->{country} orig_country=$opt->{origin_country}");
	if($opt->{services}) {
		if(
			$can_do_ground
			and ($opt->{country} eq 'US' or $opt->{country} eq 'CA')
			and $opt->{origin_country} eq 'US'
		  )
		{
			push @services, 'FEG';
			push @services, 'FEH';
		}
		if($fed) {
			for ( $fed->services() ) {
				push @services, $fe_map{$_->{service}};
			}
		}
		return join ( ($opt->{joiner} || ' '), @services);
	}
	
	if($fed and $is_express{$opt->{mode}}) {
		for ( $fed->services() ) {
			next unless $fe_map{$_->{service}} eq $opt->{mode};
			return $_->{total};
		}
		return 0;
	}

	if($opt->{mode} eq 'FEH') {
		$opt->{mode} = 'HomeD';
	}
	else {
		$opt->{mode} = 'Ground';
	}

	my @required = qw/
		function
		mode
		origin
		origin_country
		zip
		country
		weight
	/;
	my @opt = qw/
		length
		height
		width
		dimunit
		weightunit
		accessorial
	/;
	my %map = qw/
		function		func
		zip				DestZip
		country			DestCountryCode
		weight			Weight
		mode			Screen
		origin			OriginZip
		origin_country	OriginCountryCode
		length			Length
		height			Height
		width			Width
		dimunit			DimUnit
		weightunit		WeightUnit
		accessorial		AccessReturn
	/;

	$opt->{function} = 'Rate'
		unless length $opt->{function};

	my @parms;

	for(@required) {
		return $die->("Fedex mode %s: required parameter %s missing", $mode, $_)
			unless length $opt->{$_};
		push @parms, "$map{$_}=" . Vend::Util::hexify($opt->{$_});
	}
	for(@opt) {
		next unless length $opt->{$_};
		push @parms, "$map{$_}=" . Vend::Util::hexify($opt->{$_});
	}

	my $url = $opt->{target_url} . '?' . join('&', @parms);
	
	return $url if $opt->{test};
	my $return = LWP::Simple::get($url);

	return $die->('Unable to access Fedex calculator.')
		if ! length($return);
	
	my %result;
	while( $return =~ m{<!(\w+)>(.*)<!/\1>}gs ) {
		$result{$1} = $2;
	}

	return $Vend::Interpolate::Tmp->{$opt->{hashref}} = \%result
		if $opt->{hashref};

	if(! $result{TotalCharges}) {
		return $die->("Error on Fedex calculation: %s", $result{Error});
	}

	return $result{TransitTime} if $opt->{transit_time};
#Debug("mode=$opt->{mode} total=$result{TotalCharges}");
	return $result{TotalCharges};
}
EOR

