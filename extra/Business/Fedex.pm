package Business::Fedex;

=head1 NAME

Business::Fedex - fetches FedEx shipping services
and rates for a given origin and zip and a given destination country
and zip code

=head1 SYNOPSIS

  use Business::Fedex;
  my $fedex = new Business::Fedex (
	orig_country => 'US', # ISO code
	orig_zip => '90095',
	dest_country => 'US',
	dest_zip => '94402',
	);
  $fedex->packaging('Envelope'); # FedEx Enveloppe, not yours
  $fedex->getrate; # dies on error

  # OR
  # getrate can create the object directly
  my $fedex = Business::Fedex->getrate(
	orig_country => 'CA', # ISO code
	orig_zip => 'H3C3R7',
	dest_country => 'US',
	dest_zip => '94402',
	packaging => 'Envelope',
	);

  # many services might be available
  print "Service\tDelay\tDropoff\tOther\tTotal\n";
  foreach ($fedex->services) {
	# a hash ref object
	print join("\t", $_->{service},	 $_->{delay}, $_->{dropoff}, $_->{other}, $_->{total}), "\n";
  }
  print "\nCheapest:\n";
  $_ = $fedex->cheapest;
  print join("\t", $_->{service},  $_->{delay}, $_->{dropoff}, $_->{other}, $_->{total}), "\n";

  print "\nOtherDetails:\n";
  my %d = $fedex->other_details;
  foreach (keys %d) {
	 print "$_: $d{$_}\n";
  }

=head1 DESCRIPTION

This module let you fetch Federal Express shipping rates from and to any country.

The module makes a HTTP request at http://www.fedex.com/servlet/RateFinderServlet?orig_country=US&language=english
and parses the output into an array of hashes, see services method.

=cut

use strict;
use LWP::UserAgent;
use HTTP::Request::Common;

use vars qw($Debug $VERSION %iso2fedex);

$VERSION = 0.01;

$Debug = 1;

# fedex servlet we use
my $Getratecgi = "http://www.fedex.com/servlet/RateFinderServlet";


# as per form at
# http://www.fedex.com/servlet/RateFinderServlet?orig_country=US&language=english
my %Packagings = (
		'Envelope' => '6',
		'Pak' => '2',
		'Box' => '3',
		'Tube' => '4',
		'My Packaging' => '1',
	);
my %Company_types = (
	'Ground' => 1,
	'Home' => 1,
	'Express' => 1,
	);
my %Dropoff_types = (
	'Fedex' => 4,
	'Courier' => 1,
	'Pickup' => 2,
	);

# attributes and some default values
my %Attributes = (
	# hidden in original form
	'jsp_name' => 'index',
	'language' => 'english',
	'portal' => 'xx',
	'account' => '',
	'heavy_weight' => 'NO',
	'packet_zip' => '',
	'hold_packaging' => '',
	# user supplied
	orig_country => '',
	orig_zip => '',
	dest_country => '',
	dest_zip => '',
	company_type => 'Express',
	packaging => '1',
	weight => '',
	weight_units => 'lbs',
	dropoff_type => 4,
	);

# must be provided, no default values
my @Required = qw(orig_country orig_zip dest_country dest_zip packaging);

=head1 ATTRIBUTES

Following are the list of possible attributes and values for a Fedex object,
with defaults and required values highlighted

=over 4

=item orig_country

ISO-3122 country code from where the package is to be sent (your place), I<required>.

=item orig_zip

Zip code from where the package is to be sent (your place), I<required>.

=item dest_country, dest_zip

Same as orig for destination (their place), I<required>.

=item company_type

Type of Fedex service, one of: I<Express> (default), I<Ground> or I<Home>

=item packaging

How the parcel is packaged, one of I<Envelope>, I<Pak>, I<Box>, I<Tube>, I<My Packaging> (default),

=item weight

weight of shipment, I<required>, except if packaging is I<Envelope>

=item weight_units

one of I<lbs> (default) or I<kgs>

=item dropoff_type

where the shipment is to be picked up, one of I<Fedex> (a fedex centre, default),
I<courier> (scheduled pickup), I<pickup> (you will call to schedule a pickup)

=back

=head1 METHODS

=over

=item new [name => val, name => val, ...]

creates a Business Fedex object, setting attributes passed

See attr method for list of attributes

=cut

sub new {
	my $obj_or_class = shift;
	my $class = ref $obj_or_class || $obj_or_class;

	my $self = {};
	bless $self, $class;

	# assign a copy of Attributes defaults are set
	$self->{attr} = {%Attributes};

	my %attr = @_;
	# assign attributes
	foreach (keys %attr) {
		$self->attr($_, $attr{$_});
	}
	$self->{'services'} = [];
	$self->{'other_details'} = {};
	$self;
}


=item attr KEY [VALUE]

returns value of attribute KEY, setting it to VALUE if defined.

You can also say $fedex->KEY to get/set attributes (uses AUTOLOAD)

=cut


# get/set an attribute
sub attr {
	my $self = shift;
	my $key = shift;
	if(@_) {
		my $value = shift;
		# validation
		die "Invalid attribute $key"
			unless exists $Attributes{$key};
		if($key eq 'packaging'
			&& $value !~ /^\d+$/) {
			$value = $Packagings{$value}
				|| die "Invalid $key: $value";
		} elsif ($key eq 'company_type'
			&& ! defined $Company_types{$value}) {
			die "Invalid $key: $value";
		} elsif($key eq 'dropoff_type'
			&& $value !~ /^\d+$/) {
			$value = $Dropoff_types{$value}
				|| die "Invalid $key: $value";
		}
		$self->{attr}{$key} = $value;
	}
	$self->{attr}{$key};
}

sub AUTOLOAD {
	use vars qw ($AUTOLOAD);
	my $self = shift;
	my $attr = $AUTOLOAD;
	$attr =~ s/.*:://;
	if (defined $Attributes{$attr}) {
		return $self->attr($attr, @_);
	}
	die "No such attribute $attr in Business::Fedex::AUTOLOAD";
}

sub DESTROY { }

=item getrate [key => val, key => val, ...]

fetches the rates according to current attributes on FedEx site,

opitonnally creates a Business Fedex object, setting attributes passed

See services for details about fetching results.

=cut

sub getrate {
	my $obj_or_class = shift;

	my $self = ref($obj_or_class)
				? $obj_or_class
				: $obj_or_class->new(@_);

	my %attr =  %{$self->{attr}};
	foreach(@Required) {
		die "Missing required attribute $_"
			unless $attr{$_};
	}
	# weight is required unless packaging is Envelope
	die "Missing required attribute weight"
		unless $attr{'weight'} || $attr{'packaging'} == 6;

	# convert dest_country into dest_country_value
	# as the fedex servlet validate with the value
	# not the code. IF we dont convert, we get
	# Bad zip codes error
	my $code = uc delete $attr{'dest_country'};
	die "Invalid dest_country $code"
		unless $code && $iso2fedex{$code};
	$attr{'dest_country_val'} = $iso2fedex{$code};

	# simple check to see if the orig country make sense
	$iso2fedex{uc $attr{'orig_country'}}
		|| die "Origin country doesn't exist: $attr{'orig_country'}";

	# make request
	my $ua = new LWP::UserAgent;
	my $req = POST $Getratecgi,
				[%attr,
				'submit_button' => 'Get Rate', # Fedex servlet has 2 buttons
				];
	print STDERR "Business::Fedex requesting ", $req->as_string, "...\n"
		if $Debug;
	my $response = $ua->request($req);
	die "Error fetching " . $req->as_string . ":\n" . $response->error_as_HTML()
		if $response->is_error;

	#done
	my $result = $response->content;
	if ($result =~ /class='error'.*?>([^<]+)</) {
		my @errors;
		while ($result =~ /class='error'.*?>([^<]+)</g) {
			push @errors, $1;
		}
		die "Data Error processing processing request: " . join (", ", @errors);
	}
	# more generic error
	if ($result =~ /ERROR/) {
		die "Unknown Error processing request: " . $req->as_string;
	}

	# parse
	my @fields = qw(service dropoff other total);
	my ($s,$i);
	while ($result =~ m|<TD.*?class='resultstable'>(.*?)</TD>|isg) {
		$self->{'services'}->[$s]->{$fields[$i]} = $1;
		# add delay
		if($i == 0
			&& $self->{'services'}->[$s]->{$fields[$i]} =~ s|<BR>(.*)$||) {
				$self->{'services'}->[$s]->{'delay'} = $1;
				$self->{'services'}->[$s]->{'delay'} =~ s/<[^>]+>//g;
		}
		# remove tags
		$self->{'services'}->[$s]->{$fields[$i]} =~ s/<[^>]+>//g;
		# remove &reg;
		$self->{'services'}->[$s]->{$fields[$i]} =~ s/&reg;//g;
		# might have more than 1 service
		if(++$i > $#fields) {
			$s++; $i = 0;
		}
	}
	# add other details
	my ($other) = ($result =~ m|Other\s+FedEx\s+\w+\s+Service\s+Charges.+?<TABLE[^>]+>(.+?)</TABLE>|is);
	if($other) {
		while ($other =~ m|\s*<TR[^>]*>\s*<TD[^>]*>\s*(.*?)</TD>.*?</TD>\s*<TD[^>]*>\s*(.*?)<.*?</TR>\s*|isg) {
			$self->{'other_details'}->{$1} = $2;
		}
	}

	$self;
}

=item services

returns an array of services available, empty before get.

Each entry is a hash ref, with keys:

I<service> Name of Fedex service

I<dropoff> Cost at Dropoff

I<delay> delay of delivery (not always defined)

I<other> Other charges (see other_details method)

I<total> Total cost

=cut

sub services {
	my $self = shift;
	@{$self->{'services'}};
}

=item other_details

returns a hash of other details about rate, where key is the detail and value
is the cost of the detail.

Mostly used by Fedex to describe costs that appear in the Other column of services.

=cut

sub other_details {
	my $self = shift;
	%{$self->{'other_details'}};
}

=item cheapest

returns the cheapest service as a hash ref

=cut

sub cheapest {
	my $self = shift;
	my $cheapest = {};
	my $lowcost = 9999;
	foreach (@{$self->{services}}) {
		if($lowcost > $_->{total}) {
			$cheapest = $_;
			$lowcost = $_->{total};
		}
	}
	$cheapest;
}


# for debugging
sub dump {
	use Data::Dumper;
	print Dumper(shift);
}

# fedex uses names in some validation, sigh...
%iso2fedex = (
		  'LA' => 'Laos',
		  'MP' => 'Saipan',
		  'VN' => 'Vietnam',
          'SM' => 'San Marino',
          'SN' => 'Senegal',
          'KW' => 'Kuwait',
          'KY' => 'Cayman Islands',
          'SR' => 'Suriname',
          'KZ' => 'Kazakhstan',
          'DE' => 'Germany',
          'SV' => 'El Salvador',
          'SY' => 'Syria',
          'SZ' => 'Swaziland',
          'LB' => 'Lebanon',
          'DJ' => 'Djibouti',
          'LC' => 'St. Lucia',
          'DK' => 'Denmark',
          'DM' => 'Dominica',
          'DO' => 'Dominican Republic',
          'LI' => 'Liechtenstein',
          'TC' => 'Turks & Caicos Islands',
          'LK' => 'Sri Lanka',
          'TD' => 'Chad',
          'TG' => 'Togo',
          'TH' => 'Thailand',
          'LR' => 'Liberia',
          'DZ' => 'Algeria',
          'LS' => 'Lesotho',
          'LT' => 'Lithuania',
          'TM' => 'Turkmenistan',
          'LU' => 'Luxembourg',
          'TN' => 'Tunisia',
          'LV' => 'Latvia',
          'TR' => 'Turkey',
          'TT' => 'Trinidad/Tobago',
          'EC' => 'Ecuador',
          'EE' => 'Estonia',
          'TW' => 'Taiwan',
          'EG' => 'Egypt',
          'TZ' => 'Tanzania',
          'MA' => 'Morocco',
          'MC' => 'Monaco',
          'MD' => 'Moldova',
          'MG' => 'Madagascar',
          'MH' => 'Marshall Islands',
          'UA' => 'Ukraine',
          'ER' => 'Eritrea',
          'ES' => 'Spain',
          'MK' => 'Macedonia',
          'ML' => 'Mali',
          'ET' => 'Ethiopia',
          'MN' => 'Mongolia',
          'UG' => 'Uganda',
          'MO' => 'Macau',
          'MQ' => 'Martinique',
          'MR' => 'Mauritania',
          'MS' => 'Montserrat',
          'MT' => 'Malta',
          'MU' => 'Mauritius',
          'MV' => 'Maldives',
          'MW' => 'Malawi',
          'MX' => 'Mexico',
          'MY' => 'Malaysia',
          'MZ' => 'Mozambique',
          'US' => 'U.S.A.',
          'UY' => 'Uruguay',
          'UZ' => 'Uzbekistan',
          'NA' => 'Namibia',
          'FI' => 'Finland',
          'FJ' => 'Fiji',
          'NC' => 'New Caledonia',
          'NE' => 'Niger',
          'FM' => 'Micronesia',
          'NG' => 'Nigeria',
          'FO' => 'Faroe Islands',
          'VA' => 'Vatican City',
          'NI' => 'Nicaragua',
          'FR' => 'France',
          'VC' => 'St. Vincent',
          'NL' => 'Netherlands',
          'VE' => 'Venezuela',
          'NO' => 'Norway',
          'VG' => 'British Virgin Islands',
          'NP' => 'Nepal',
          'VI' => 'U.S. Virgin Islands',
          'NZ' => 'New Zealand',
          'GA' => 'Gabon',
          'GB' => 'United Kingdom',
          'VU' => 'Vanuatu',
          'GD' => 'Grenada',
          'GE' => 'Georgia',
          'GF' => 'French Guiana',
          'GH' => 'Ghana',
          'GI' => 'Gibraltar',
          'GL' => 'Greenland',
          'GM' => 'Gambia',
          'GN' => 'Guinea',
          'GP' => 'Guadeloupe',
          'GQ' => 'Equatorial Guinea',
          'GR' => 'Greece',
          'GT' => 'Guatemala',
          'OM' => 'Oman',
          'GU' => 'Guam',
          'WF' => 'Wallis & Futuna',
          'GY' => 'Guyana',
          'PA' => 'Panama',
          'HK' => 'Hong Kong',
          'PE' => 'Peru',
          'PF' => 'French Polynesia',
          'HN' => 'Honduras',
          'PG' => 'Papua New Guinea',
          'PH' => 'Philippines',
          'HR' => 'Croatia',
          'PK' => 'Pakistan',
          'PL' => 'Poland',
          'HT' => 'Haiti',
          'HU' => 'Hungary',
          'PR' => 'Puerto Rico',
          'PT' => 'Portugal',
          'AD' => 'Andorra',
          'AE' => 'United Arab Emirates',
          'PW' => 'Palau',
          'AG' => 'Antigua',
          'PY' => 'Paraguay',
          'AI' => 'Anguilla',
          'AL' => 'Albania',
          'ID' => 'Indonesia',
          'AM' => 'Armenia',
          'IE' => 'Ireland',
          'AN' => 'Netherlands Antilles',
          'AO' => 'Angola',
          'QA' => 'Qatar',
          'AR' => 'Argentina',
          'AS' => 'American Samoa',
          'AT' => 'Austria',
          'IL' => 'Israel',
          'AU' => 'Australia',
          'IN' => 'India',
          'AW' => 'Aruba',
          'AZ' => 'Azerbaijan',
          'IS' => 'Iceland',
          'IT' => 'Italy',
          'YE' => 'Yemen',
          'BB' => 'Barbados',
          'BD' => 'Bangladesh',
          'BE' => 'Belgium',
          'BF' => 'Burkina Faso',
          'BG' => 'Bulgaria',
          'BH' => 'Bahrain',
          'BI' => 'Burundi',
          'BJ' => 'Benin',
          'BM' => 'Bermuda',
          'BN' => 'Brunei',
          'BO' => 'Bolivia',
          'BR' => 'Brazil',
          'BS' => 'Bahamas',
          'BT' => 'Bhutan',
          'RE' => 'Reunion',
          'JM' => 'Jamaica',
          'BW' => 'Botswana',
          'JO' => 'Jordan',
          'JP' => 'Japan',
          'ZA' => 'South Africa',
          'BY' => 'Belarus',
          'BZ' => 'Belize',
          'RO' => 'Romania',
          'CA' => 'Canada',
          'ZM' => 'Zambia',
          'RU' => 'Russian Federation',
          'CD' => 'Congo Democratic Republic of',
          'RW' => 'Rwanda',
          'CG' => 'Congo Brazzaville',
          'CH' => 'Switzerland',
          'CI' => 'Ivory Coast',
          'CK' => 'Cook Islands',
          'CL' => 'Chile',
          'CM' => 'Cameroon',
          'KE' => 'Kenya',
          'ZW' => 'Zimbabwe',
          'CN' => 'China',
          'CO' => 'Colombia',
          'KG' => 'Kyrgyzstan',
          'KH' => 'Cambodia',
          'SA' => 'Saudi Arabia',
          'CR' => 'Costa Rica',
          'SC' => 'Seychelles',
          'SE' => 'Sweden',
          'KN' => 'St. Kitts/Nevis',
          'CV' => 'Cape Verde',
          'SG' => 'Singapore',
          'SI' => 'Slovenia',
          'CY' => 'Cyprus',
          'KR' => 'South Korea',
          'CZ' => 'Czech Republic',
          'SK' => 'Slovak Republic',
          'SL' => 'Sierra Leone'
);

=back

=head1 BUGS

None so far, contact author if any

=head1 SEE ALSO

LWP

=head1 AUTHOR

Francois Belanger, francois@sitepak.com

=cut


#########
1;
