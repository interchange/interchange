UserTag shipengine Order mode weight
UserTag shipengine AddAttr
UserTag shipengine Routine <<EOR
sub {
    my ($mode, $weight, $opts) = @_;
    my $service = $mode || $opts->{service};
    require Vend::Ship::ShipEngine;
    my $logger = sub {
        my $msg = errmsg(@_);
        Log($msg, { file => $::Variable->{SHIPENGINE_LOG_FILE} || "var/log/shipengine.log" });
    };
    my %args = (
                logger => $logger,
                api_key => $::Variable->{SHIPENGINE_API_KEY},
               );
    if (my $debug = $::Variable->{SHIPENGINE_DEBUG_FILE}) {
        $args{tracer} = sub {
            my $msg = errmsg(@_);
            Log($msg, { file => $debug });
        };
    }
    my $se = Vend::Ship::ShipEngine->new(%args);
    if ($opts->{carrier_summary}) {
        return $se->show_carrier_summary({ json => 1 });
    }
    my %from;
    foreach my $f (qw/name company_name phone
                      address_line1 address_line2
                      state_province
                      city_locality
                      postal_code country_code
                     /) {
        if (my $v = $::Variable->{"SHIPENGINE_FROM_" . uc($f)}) {
            $from{$f} = $v;
        }
    }
    my %vmap = (
                name => [qw/fname lname/],
                company_name => 'company',
                phone => 'phone_day',
                address_line1 => 'address1',
                address_line2 => 'address2',
                city_locality => 'city',
                state_province => 'state',
                postal_code => 'zip',
                country_code => 'country',
               );
    my %to;
    foreach my $k (keys %vmap) {
        my $vk = $vmap{$k};
        if (ref($vk)) {
            $to{$k} = join(' ', grep { $_ } map { $::Values->{$_} } @$vk);
        }
        else {
            $to{$k} = $::Values->{$vk};
        }
    }
    my $req = {
               shipment => {
                            comparison_rate_type => "retail",
                            ship_from => \%from,
                            ship_to => \%to,
                            confirmation => "delivery",
                            packages => [
                                         {
                                          package_code => 'package', # indicates a custom or unknown package type.
                                          weight => {
                                                     value => ($weight || 0) + 0,
                                                     unit => 'pound',
                                                    },
                                         },
                                        ],
                           },
               rate_options => {
                                carrier_ids => [ split(/[ ,]+/, $::Variable->{SHIPENGINE_CARRIERS}) ],
                               }
              };
    my $serialized = $se->serialize_structure($req);
    my $res;
    if (my $got = $::Session->{_shipengine_last_request}) {
        if ($got->{response} and $got->{request} eq $serialized) {
            if (time() < $got->{expire}) {
                $res = $got->{response};
            }
            else {
                $se->logger->("Cache expired");
            }
        }
        else {
            $se->logger->("Cache invalid");
        }
    }
    else {
        $se->logger->("No cache found");
    }
    if (my $got = $::Session->{_shipengine_last_request}) {
        $logger->("Found the cache in the session");
        if ($got->{response} and $got->{request} eq $serialized and (time() < $got->{expire})) {
            $res = $got->{response};
        }
    }
    unless ($res) {
        $logger->("Doing query for $serialized");
        $res = $se->api_call(POST => '/v1/rates', $req);
        if ($res->{data} and $res->{data}->{errors}) {
            if (ref($res->{data}->{errors}) eq 'ARRAY') {
                $::Session->{ship_message} .= join(' ', map { $_->{message} // '' } @{$res->{data}->{errors}});
            }
        }
        $::Session->{_shipengine_last_request} = {
                                                  expire => $res->{success} ? time() + 3600 : time() + 5,
                                                  request => $serialized,
                                                  response => $res,
                                                 };
    }
    # now search all the rates for a matching carrier + service
    my $out = 0;
    if ($opts->{output_debug}) {
        return $se->serialize_structure($res->{data}->{rate_response});
    }
    if ($service) {
        if ($res and $res->{data} and $res->{data}->{rate_response} and $res->{data}->{rate_response}->{rates}) {
            my @rates = @{$res->{data}->{rate_response}->{rates}};
            unless (@rates) {
                @rates = @{$res->{data}->{rate_response}->{invalid_rates}};
                $logger->("Using invalid rates");
            }
            foreach my $rate (grep { $_->{service_code} eq $service } @rates) {
                # pick the highest if multiple
                my $total = 0;
                # $logger->("Rate are " . uneval($rate));
                foreach my $break (qw/requested_comparison/) {
                    if (my $add = $rate->{"${break}_amount"}) {
                        if (my $amount = $add->{amount}) {
                            $total += $amount;
                        }
                    }
                }
                if ($total > $out) {
                    $out = $total;
                }
            }
        }
    }
    $logger->("Returning $out for $service");
    return $out;
}
EOR

UserTag shipengine Documentation <<EOD

=head1 NAME

shipengine -- calculate shipping rates over the ShipEngine REST API

=head1 SYNOPSIS

  # suitable for shipping.asc
  [shipengine mode="ups_ground" weight=3]

  # for debugging
  [shipengine weight=3 output_debug=1]
  [shipengine show_modes=1]

=head1 DESCRIPTION

Calculate shipping rates over the ShipEngine REST API. See
L<https://www.shipengine.com/docs/rates/>

The tag is meant to be used in shipping.asc calling it with the mode
and the total weight:

  [shipengine mode="01" weight="@@TOTAL@@"]

The destination of the packages is taken from the user values.

=head2 OPTIONS

=over 4

=item weight

Weight in pounds. (required)

=item mode

Any supported service code. Call [shipengine carrier_summary=1] to see
them.

to see them.

=item output_debug

If set to a true value, return all the rate informations collected
from the API and formatted with JSON.

=item carrier_summary

If set to a true value, return the available carriers and service
codes with their names.

=back

=head1 VARIABLES

You need this stanza in your catalog.cfg:

  Variable SHIPENGINE_LOG_FILE var/log/shipengine.log
  # optional debug file with full requests/response
  # Variable SHIPENGINE_DEBUG_FILE var/log/shipengine.debug.log
  # to use the sandbox, get a sandbox api key.
  Variable SHIPENGINE_API_KEY my_api_key_xxxxxxxxxxxxxxxxxxxxxxxxxxx
  Variable SHIPENGINE_FROM_NAME -
  Variable SHIPENGINE_FROM_COMPANY_NAME My Company
  Variable SHIPENGINE_FROM_ADDRESS_LINE1 My Address
  Variable SHIPENGINE_FROM_PHONE XXX-XXX-XXXX
  Variable SHIPENGINE_FROM_CITY_LOCALITY My City
  Variable SHIPENGINE_FROM_POSTAL_CODE 99999
  Variable SHIPENGINE_FROM_COUNTRY_CODE US
  Variable SHIPENGINE_FROM_STATE_PROVINCE NY
  Variable SHIPENGINE_CARRIERS se-11111111 se-2222222

Most of the variables should be clear, as we need to set the origin of
the package. You need only the ShipEngine API key to get started.

To fill the SHIPENGINE_CARRIERS variable (multiple values separated by
white space) you need to know the carrier codes. Call:

[shipengine carrier_summary=1]

to get check them and see which shipping modes are
available for your account.

=head1 AUTHOR

Marco Pessotto <mpessotto@endpointdev.com>, End Point Corp.

EOD
