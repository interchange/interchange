#!perl

use strict;
use warnings;
use lib 'lib';

use Test::More;
use Data::Dumper;

use Vend::Server;
use Vend::Config;

*check_is_robot = *Vend::Server::check_is_robot;

my $robot_cfg_path = "dist/robots.cfg";

my @robot_uas     = read_file("t/robot_ua/ua.robot");
my @not_robot_uas = read_file("t/robot_ua/ua.norobot");

=for docs

We have to mock a few things for the testing:

Request environment:
- $CGI::remote_addr
- $CGI::remote_host
- $CGI::host
- $CGI::useragent

Configuration:
- Global::RobotIP
- Global::RobotUA
- Global::NotRobotUA

=cut

local $CGI::remote_addr = "127.0.0.1";
local $CGI::remote_host = "example.com";
local $CGI::host = "localhost";

parse_robot_cfg($robot_cfg_path);

# some sanity checks here

ok( $Global::RobotIP,      "RobotIP regex exists"    );
ok( $Global::RobotHost,    "RobotHost regex exists"  );
ok( $Global::RobotUA,      "RobotUA regex exists"    );
ok( $Global::NotRobotUA,   "NotRobotUA regex exists" );
#ok( $Global::RobotUAFinal, "RobotUAFinal regex was created implicitly");

# check various hard-coded UA strings that should/shouldn't get flagged as robots
for my $ua (@robot_uas) {
    is(check_is_robot($ua), 1);
}

for my $ua (@not_robot_uas) {
    is(check_is_robot($ua), 0);
}

done_testing();

sub parse_robot_cfg {
    my $path = shift;
    die "No such file '$path'!\n" unless $path && -f $path;

    my $robot_lines = read_file($path);

    my %D;

    for my $directive (qw/RobotUA NotRobotUA RobotIP RobotHost/) {
        # assuming these are and will stay here-docs
        if ($robot_lines =~ m/$directive <<(\w+)(.*?)^\1/imsg) {
            my $routine = $directive eq 'RobotUA' ? \&Vend::Config::parse_list_robotua : \&Vend::Config::parse_list_wildcard;

            my $string = $2;
            $string =~ s/\n//msg;

            my $value = $routine->($directive, $string);

            no strict 'refs';
            ${"Global::$directive"} = qr/$value/;
        }
    }
}

sub read_file {
    my $path = shift;

    open my $fh, '<', $path or die "no such file: $path";

    local $/ unless wantarray;
    return <$fh>; # implicit close
}
