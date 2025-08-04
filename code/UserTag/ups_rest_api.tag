UserTag ups_rest_api Order mode weight
UserTag ups_rest_api addAttr
UserTag ups_rest_api Routine <<EOR
sub {
    my ($mode, $weight, $opts) = @_;
    require Vend::Ship::UPS::REST;
    my $logger = sub {
        my $msg = errmsg(@_);
        Log($msg, { file => $::Variable->{UPS_REST_API_LOG_FILE} || "var/log/ups_rest_api.log" });
    };
    my %args = (
                logger => $logger,
                cache_dir => $::Variable->{UPS_REST_API_CACHE_DIR} || "var/ups_rest_api",
               );
    foreach my $k (qw/client_id client_secret endpoint/) {
        $args{$k} = $Variable->{'UPS_REST_API_' . uc($k)};
        unless ($args{$k}) {
            $logger->("Missing mandatory setting $k");
            return;
        }
    }
    if (my $debug = $::Variable->{UPS_REST_API_DEBUG_FILE}) {
        $args{tracer} = sub {
            my $msg = errmsg(@_);
            Log($msg, { file => $debug });
        };
    }
    my $ups = Vend::Ship::UPS::REST->new(%args);
    if ($opts->{show_modes}) {
        return $ups->serialize_structure_pp($ups->service_codes);
    }
    my (%from, %to);
    foreach my $k (qw/name address1 address2 city state zip country shipper_number/) {
        $from{$k} = $::Variable->{'UPS_REST_API_FROM_' . uc($k) };
    }
    foreach my $k (qw/fname lname company address1 address2 city state zip country/) {
        $to{$k} = $::Values->{$k};
    }
    my $req = {
        RateRequest =>  {
            Request =>  {
                TransactionReference =>  {
                    CustomerContext =>  'dummy',
                },
            },
            Shipment =>  {
                Shipper =>  {
                    Name =>  $from{name},
                    ShipperNumber =>  $from{shipper_number},
                    Address =>  {
                        AddressLine =>  [ grep { $_ } ($from{address1}, $from{address2}) ],
                        City =>  $from{city},
                        StateProvinceCode =>  $from{state},
                        PostalCode =>  $from{zip},
                        CountryCode => $from{country},
                    }
                },
                ShipTo =>  {
                    Name =>  join(' ', grep { $_ } ($to{fname}, $to{lname}, $to{company})),
                    Address =>  {
                        AddressLine =>  [ grep { $_ } ($to{address1}, $to{address2}) ],
                        City =>  $to{city},
                        StateProvinceCode =>  $to{state},
                        PostalCode =>  $to{zip},
                        CountryCode => $to{country},
                    },
                },
                NumOfPieces =>  "1",
                Package =>  {
                    PackagingType =>  {
                        Code =>  "02",
                        Description =>  "Packaging"
                    },
                    Dimensions =>  {
                        UnitOfMeasurement =>  {
                            Code =>  "IN",
                            Description =>  "Inches"
                        },
                        Length =>  "1",
                        Width =>  "1",
                        Height =>  "1",
                    },
                    PackageWeight =>  {
                        UnitOfMeasurement =>  {
                            Code =>  "LBS",
                            Description =>  "Pounds"
                        },
                        Weight =>  $weight,
                    },
                }
            }
        }
    };
    if ($::Variable->{UPS_REST_API_NEGOTIATED_RATES}) {
        $req->{RateRequest}->{Shipment}->{ShipmentRatingOptions}->{NegotiatedRatesIndicator} = "Y";
    }
    my $serialized = $ups->serialize_structure($req);
    my $res;
    if (my $got = $::Session->{_ups_rest_api_last_request}) {
        if ($got->{response} and $got->{request} eq $serialized) {
            if (time() < $got->{expire}) {
                # $ups->logger->("Using cached response");
                $res = $got->{response};
            }
            else {
                $ups->logger->("Cache expired");
            }
        }
        else {
            $ups->logger->("Cache invalid");
        }
    }
    else {
        $ups->logger->("No cache found");
    }
    unless ($res) {
        $ups->logger->("Doing actual call");
        # populate the id after the caching
        $req->{RateRequest}->{Request}->{TransactionReference}->{CustomerContext} = sprintf('rate-%s-%s',
                                                                                            $::Session->{ohost},
                                                                                            time());
        $res = $ups->safe_api_call(POST => '/api/rating/v2403/Shop' => $req);
        if ($res->{data}
            and $res->{data}->{response}
            and $res->{data}->{response}->{errors}) {
            my $errors = $res->{data}->{response}->{errors};
            if (ref($errors) eq 'ARRAY') {
                $::Session->{ship_message} .= join(' ', map { $_->{message} // '' } @$errors);
            }
        }
        $::Session->{_ups_rest_api_last_request} = {
                                                  expire => $res->{success} ? time() + 3600 : time() + 5,
                                                  request => $serialized,
                                                  response => $res,
                                                 };
    }
    my $service_codes = $ups->service_codes;
    my @all;
    if ($res->{success}
        and $res->{data}
        and $res->{data}->{RateResponse}
        and $res->{data}->{RateResponse}->{RatedShipment}
        and ref($res->{data}->{RateResponse}->{RatedShipment}) eq 'ARRAY') {
        foreach my $shipment (@{ $res->{data}->{RateResponse}->{RatedShipment} }) {
            my $rate = {
                service_code => $shipment->{Service}->{Code},
                published_rate => $shipment->{TotalCharges}->{MonetaryValue},
            };
            if (my $negotiated = $shipment->{NegotiatedRateCharges}) {
                $rate->{negotiated} = $negotiated->{TotalCharge}->{MonetaryValue};
            }
            $rate->{service_name} = $service_codes->{$rate->{service_code}} || {};
            push @all, $rate;
        }
    }
    if ($opts->{output_debug}) {
        return $ups->serialize_structure_pp(\@all);
    }
    my $out = 0;
    if ($mode) {
        my $selected;
      RATE:
        foreach my $rate (@all) {
            if ($rate->{service_code} eq $mode) {
                $selected = $rate;
                last RATE;
            }
            else {
                foreach my $alias (@{ $rate->{service_name}->{aliases} || []}) {
                    if (lc($mode) eq lc($alias)) {
                        $selected = $rate;
                        last RATE;
                    }
                }
            }
        }
        if ($selected) {
            $ups->logger->("Selected rate is " . ::uneval($selected));
            $out = $selected->{negotiated} || $selected->{published_rate};
        }
    }
    return $out;
}
EOR

UserTag ups_rest_api Documentation <<EOD

=head1 NAME

ups-rest-api -- calculate UPS rates over the REST API

=head1 SYNOPSIS

  # suitable for shipping.asc
  [ups-rest-api mode="upsg" weight=3]

  # for debugging
  [ups-rest-api weight=3 output_debug=1]
  [ups-rest-api show_modes=1]

=head1 DESCRIPTION

Calculate UPS rates over the REST API. The tag is meant to be used in
shipping.asc calling it with the mode and the total weight:

  [ups-rest-api mode="01" weight="@@TOTAL@@"]

The destination of the packages is taken from the user values.

=head2 OPTIONS

=over 4

=item weight

Weight in pounds. (required)

=item mode

Any UPS service code: See
L<https://developer.ups.com/api/reference/shipping/appendix2?loc=en_US>

You can also pass legacy codes like C<upsg>. Call [ups-rest-api show_modes=1]
to see them.

=item output_debug

If set to a true value, return all the rate informations collected
from the API and formatted with JSON.

=item show_modes

If set to a true value, return the available service codes with their
names and the supported aliases.

=back

=head1 VARIABLES

If called without the proper variables set, this tag will crash.

You need this stanza in your catalog.cfg:

  Variable UPS_REST_API_LOG_FILE var/log/ups_rest_api.log
  # optional debug file with full requests/response
  Variable UPS_REST_API_DEBUG_FILE var/log/ups_rest_api.debug.log
  Variable UPS_REST_API_CLIENT_ID XXXXXX
  Variable UPS_REST_API_CLIENT_SECRET XXXXXXX
  # production endpoint:
  # Variable UPS_REST_API_ENDPOINT https://onlinetools.ups.com
  # this is the sandbox:
  Variable UPS_REST_API_ENDPOINT https://wwwcie.ups.com
  Variable UPS_REST_API_NEGOTIATED_RATES 1
  Variable UPS_REST_API_FROM_NAME My Company
  Variable UPS_REST_API_FROM_SHIPPER_NUMBER XXXXXX
  Variable UPS_REST_API_FROM_ADDRESS1 My Address
  Variable UPS_REST_API_FROM_CITY My City
  Variable UPS_REST_API_FROM_STATE NY
  Variable UPS_REST_API_FROM_ZIP 99999
  Variable UPS_REST_API_FROM_COUNTRY US

Most of the variables should be clear, as we need to set the origin of
the package. As shown above, there are two endpoints available, one
for the sandbox and one for production.

Set C<UPS_REST_API_NEGOTIATED_RATES> to a true value if you have
negotiated rates.

To get the client id and the client secret, you need to login and
create an App at L<https://developer.ups.com/apps>. You only need to
subscribe to the Rating API.

The Shipper Number is called "Billing Account Number" in the App page
where you can find the credentials.

=head1 AUTHOR

Marco Pessotto <mpessotto@endpointdev.com>, End Point Corp.

EOD


# Local Variables:
# mode: cperl
# cperl-indent-parens-as-block: t
# End:
