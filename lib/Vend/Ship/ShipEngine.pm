package Vend::Ship::ShipEngine;

use strict;
use warnings;
use Data::Dumper;

# in cpanfile
use LWP::UserAgent;
use JSON (qw/encode_json decode_json/);

sub new {
    my ($class, %args) = @_;
    my $ua = LWP::UserAgent->new(timeout => 30);
    my $self = {
                logger => sub {},
                tracer => sub {},
                ua => $ua,
                api_key => undef,
               };
    foreach my $k (keys %$self) {
        if (defined $args{$k}) {
            $self->{$k} = $args{$k};
        }
        die "$k is required" unless $self->{$k};
    }
    bless $self, $class;
}

sub api_key { shift->{api_key} }
sub tracer  { shift->{tracer} }
sub logger  { shift->{logger} }
sub ua      { shift->{ua} }

sub serialize_structure {
    my ($self, $struct) = @_;
    return JSON->new->canonical->ascii->pretty->encode($struct);
}

sub api_call {
    my ($self, @args) = @_;
    my %out;
    eval {
        my $res = $self->_api_call(@args);
        if ($res->content_type =~ m{application/json}i) {
            if (my $content = $res->content) {
                $out{data} = decode_json($content);
            }
            else {
                $out{data} = undef;
            }
        }
        else {
            $out{text} = $res->decoded_content;
        }
        $out{success} = $res->is_success;
    };
    if ($@) {
        $out{error} = $@;
    }
    return \%out;
}

sub _api_call {
    my ($self, $method, $path, $payload, $options) = @_;
    die "Bad usage" unless $method && $path;
    my $p = $payload ? encode_json($payload) : '';
    $self->tracer->("Payload is " . Dumper($payload));
    my @args = ($method);
    my $uri = URI->new('https://api.shipengine.com');
    $uri->path($path);
    $uri->query_form({
                      %{ $options || {} }
                     });
    push @args, $uri, [
                       'API-Key' => $self->api_key,
                       'Content-Type' => 'application/json',
                       'Accept' => 'application/json',
                      ];
    push @args, $p if $p;
    my $req = HTTP::Request->new(@args);
    $self->tracer->($req->as_string);
    my $res = $self->ua->request($req);
    $self->tracer->($res->as_string);
    return $res;
}

sub show_carrier_summary {
    my ($self, $opts) = @_;
    my $res = $self->api_call(GET => '/v1/carriers');
    my @out;
    if ($res->{success} and $res->{data}) {
        foreach my $carrier (@{$res->{data}->{carriers} || []}) {
            my $details = {
                           carrier_code => $carrier->{carrier_code},
                           carrier_id => $carrier->{carrier_id},
                           services => [],
                           packages => [],
                          };
            foreach my $service (@{ $carrier->{services} || [] }) {
                push @{$details->{services}}, "$service->{service_code}: $service->{name}";
            }
            foreach my $package (@{ $carrier->{packages} || [] }) {
                push @{$details->{packages}}, "$package->{package_code}: $package->{name}";
            }
            push @out, $details;
        }
    }
    if ($opts->{json}) {
        return JSON->new->canonical->ascii->pretty->encode(\@out);
    }
    return \@out;
}

1;
