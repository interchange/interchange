package Vend::Ship::UPS::REST;

use strict;
use warnings;

# http://perlpunks.de/corelist/
use File::Spec::Functions qw/catfile catdir/;
use File::Path ();
use File::Copy qw/move/;
use Data::Dumper;
# in cpanfile
use JSON;
use LWP::UserAgent;
# lwp's deps
use URI;
use HTTP::Headers;
use HTTP::Request;

sub new {
    my ($class, %args) = @_;
    my $ua = LWP::UserAgent->new(timeout => 30);
    my $self = {
                endpoint => undef,
                client_id => undef,
                client_secret => undef,
                cache_dir => 'var/ups_rest_api',
                logger => sub {},
                tracer => sub {},
                ua => $ua,
               };
    foreach my $k (keys %$self) {
        if (defined $args{$k}) {
            $self->{$k} = $args{$k};
        }
        die "$k is required" unless $self->{$k};
    }
    bless $self, $class;
}

sub endpoint      { shift->{endpoint} };
sub client_id     { shift->{client_id} };
sub client_secret { shift->{client_secret} };
sub cache_dir     { shift->{cache_dir} };
sub logger        { shift->{logger} };
sub tracer        { shift->{tracer} };
sub ua            { shift->{ua} };

sub oath_token_endpoint {
    my $self = shift;
    my $uri = URI->new($self->endpoint);
    $uri->path('/security/v1/oauth/token');
    return $uri;
}

sub cache_file {
    my $self = shift;
    $self->{cache_file} ||= $self->_build_cache_file;
    return $self->{cache_file};
}

sub _build_cache_file {
    my $self = shift;
    my $dir = $self->cache_dir or die "missing cache_dir";
    File::Path::make_path($dir, { chmod => 0700 });
    return File::Spec->catfile($dir, 'token.json');
}

sub get_new_token {
    my $self = shift;
    my $h = HTTP::Headers->new('Content-Type' => 'application/x-www-form-urlencoded');
    $self->logger->("Requiring new token");
    $h->authorization_basic($self->client_id, $self->client_secret);
    my $req = HTTP::Request->new(POST => $self->oath_token_endpoint, $h,
                                 'grant_type=client_credentials');
    # $self->logger->($req->as_string);
    my $res = $self->ua->request($req);
    $self->tracer->("Token request " . join(" ", $req->as_string, $res->as_string));
    if ($res->is_success) {
        my $content = $res->content;
        my $data = decode_json($content);
        my $temporary = $self->cache_file . $$ . time();
        open (my $fh, '>:raw', $temporary) or die "Cannot open $temporary $!";
        print $fh $content;
        close $fh;
        # atomic write
        move($temporary, $self->cache_file);
        return $data;
    }
    else {
        die "Cannot retrieve the token! Status line is "
          . $res->status_line . " " . ($res->content || '');
    }
}

sub get_token {
    my $self = shift;
    my $cache = $self->cache_file;
    my $data;
    # get from file if exists
    if (-f $cache) {
        open (my $fh, '<:raw', $cache) or die "Cannot open $cache $!";
        local $/ = undef;
        my $json = <$fh>;
        close $fh;
        eval {
            $data = decode_json($json);
        };
        my $mtime = (stat($cache))[9];
        if ($data->{expires_in}
            and $data->{access_token}
            and ((time() - $mtime + 60) < $data->{expires_in})) {
            return $data;
        }
    }
    return $self->get_new_token;
}

sub safe_api_call {
    my ($self, @args) = @_;
    my $ret;
    eval {
        $ret = $self->api_call(@args);
    };
    if (my $err = $@) {
        $self->logger->("Fatal error: $err");
        $ret = {
                data => undef,
                error => "$err",
               };
    }
    return $ret;
}

sub api_call {
    my ($self, @args) = @_;
    my $res = $self->_do_api_call(@args);
    # if 401 get a new token and repeat.
    if (!$res->is_success and $res->code == 401) {
        $self->get_new_token;
        $res = $self->_do_api_call(@args);
    }
    my %out = (
               text => $res->decoded_content,
               request => \@args,
              );
    if ($res->content_type =~ m{application/json}i) {
        if (my $content = $res->content) {
            $out{data} = decode_json($content);
        }
        else {
            $out{data} = undef;
        }
    }
    if ($res->is_success) {
        $out{success} = 1;
    }
    else {
        $out{error} = "Failure " . $res->status_line . ": " . $out{text};
        $self->logger->($out{error});
    }
    return \%out;
}

sub _do_api_call {
    my ($self, $method, $path, $payload, $options) = @_;
    die "Bad usage" unless $method && $path;
    my $p = $payload ? encode_json($payload) : '';
    my @args = ($method);
    my $uri = URI->new($self->endpoint);
    $uri->path($path);
    if ($options) {
        $uri->query_form($options);
    }
    push @args, $uri, [
                       'Content-Type' => 'application/json',
                       Authorization => "Bearer " . $self->get_token->{access_token},
                      ];
    push @args, $p if $p;

    $self->logger->(qq{$method $uri $p});
    my $req = HTTP::Request->new(@args);
    $self->tracer->("My request is " . $req->as_string);
    my $res = $self->ua->request($req);
    $self->tracer->("My response is " . $res->as_string);
    $self->logger->("Status line is " . $res->status_line);
    return $res;
}


# https://developer.ups.com/api/reference/shipping/appendix2?loc=en_US + [ups-net-query]
sub service_codes {

    # legacy codes from ups-net-query.tag Unclear UPS_SAVER what is it
# 	my %service = (
#       '1DA' => 'NEXT_DAY_AIR',
#       'upsr' => 'NEXT_DAY_AIR',
#       '2DA' => '2ND_DAY_AIR',
#       'upsb' => '2ND_DAY_AIR',
#       'GND' => 'GROUND',
#       'upsg' => 'GROUND',
#       'XPR' => 'WORLDWIDE_EXPRESS',
#       'XPD' => 'WORLDWIDE_EXPEDITED',
#       'STD' => 'STANDARD',
#       'cang' => 'STANDARD',
#       '3DS' => '3_DAY_SELECT',
#       'ups3' => '3_DAY_SELECT',
#       '1DP' => 'NEXT_DAY_AIR_SAVER',
#       'upsrs' => 'NEXT_DAY_AIR_SAVER',
#       '1DM' => 'NEXT_DAY_AIR_EARLY_AM',
#       'XDM' => 'WORLDWIDE_EXPRESS_PLUS',
#       '2DM' => '2ND_DAY_AIR_AM',
#       'upsbam' => '2ND_DAY_AIR_AM',
#       'SVR' => 'UPS_SAVER',
# 	);
    #  Shipments originating in United States

    return {
            '11' => { name => "UPS Standard", aliases => [qw/STD cang/] },
            '08' => { name => "UPS Worldwide Expedited", aliases => [qw/XPD/] },
            '07' => { name => "UPS Worldwide Express", aliases => [qw/XPR/] },
            '54' => { name => "UPS Worldwide Express Plus", aliases => [qw/XDM/] },
            '65' => { name => "UPS Worldwide Saver", aliases => [qw//] },
            '02' => { name => "UPS 2nd Day Air", aliases => [qw/2DA upsb/] },
            '59' => { name => "UPS 2nd Day Air A.M.", aliases => [qw/2DM upsbam/] },
            '12' => { name => "UPS 3 Day Select", aliases => [qw/3DS ups3/] },
            'M4' => { name => "UPS Expedited Mail Innovations", aliases => [qw//] },
            'M2' => { name => "UPS First-Class Mail", aliases => [qw//] },
            '03' => { name => "UPS Ground", aliases => [qw/GND upsg/] },
            '01' => { name => "UPS Next Day Air", aliases => [qw/1DA upsr/] },
            '14' => { name => "UPS Next Day Air Early", aliases => [qw/1DM/] },
            '13' => { name => "UPS Next Day Air Saver", aliases => [qw/1DP upsrs/] },
            'M3' => { name => "UPS Priority Mail", aliases => [qw//] },
           };
}

sub serialize_structure {
    my ($self, $struct) = @_;
    return JSON->new->canonical->ascii->encode($struct);
}

sub serialize_structure_pp {
    my ($self, $struct) = @_;
    return JSON->new->canonical->ascii->pretty->encode($struct);
}

1;

