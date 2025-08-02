use Plack::Builder;
use Plack::App::WrapCGI;

builder {

    # restart interchange
    my $ic = `/home/interchange/interchange/bin/interchange -r`;
    print $ic ? $ic . "\n" : "ERROR: failed to restart interchange\n";

    # Interchange requires REMOTE_HOST to be set to an ip address
    ## by default HTTP::Server::PSGI sets REMOTE_HOST to localhost
    ## so we are overriding it with the value in REMOTE_ADDR
    enable 'ReviseEnv', revisors => { 'REMOTE_HOST' => '[% ENV:REMOTE_ADDR %]' };

    # Static files
    enable 'Static',
      path => qr{^/(images|js|css|interchange-5)/},
      root => '/home/interchange/catalogs/static/';

    enable 'Static',
      path => qr{^/(demo)/(images|js|css|interchange-5)/},
      root => '/home/interchange/catalogs/static/';

    # Mount paths
    mount '/demo' => Plack::App::WrapCGI->new( script => '/home/interchange/catalogs/bin/demo', execute => 1 )->to_app;

};
