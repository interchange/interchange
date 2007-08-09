#!/usr/bin/perl

# tlink.pl: runs as a cgi program and passes request to Interchange server
#
# $Id: mod_perl_tlink.pl,v 2.4 2007-08-09 13:40:52 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

require 5.005;
use strict;
use Apache::Registry;
use Socket;
my @port_pool = (
	7786,
);

my $LINK_TIMEOUT = 10;
#my $LINK_TIMEOUT = ~_~LINK_TIMEOUT~_~;
my $LINK_PORT    = $ENV{MINIVEND_PORT} || 7786;
#my $LINK_PORT    = $ENV{MINIVEND_PORT} || ~_~LINK_HOST~_~;
my $LINK_HOST    = 'localhost';
#my $LINK_HOST    = '~_~LINK_HOST~_~';
my $ERROR_ACTION = "-notify";

# Uncomment this if you want to rotate ports....set port_pool above.
# Will increase MV performance if you use multiple ports.
#my $LINK_PORT    = $port_pool[ int( rand (scalar @port_pool) ) ];

$ENV{PATH} = "/bin:/usr/bin";
$ENV{IFS} = " ";

my (%exclude_header) = qw/
		SERVER_SIGNATURE    1
		HTTP_ACCEPT_CHARSET 1
		HTTP_ACCEPT         1
		PATH                1
		IFS                 1
/;

my $r = Apache->request();
my $arg;
my $env;
my $ent;


# Return this message to the browser when the server is not running.
# Log an error log entry if set to notify

sub server_not_running {

	my $msg;

	if($ERROR_ACTION =~ /not/i) {
		warn "ALERT: Interchange server not running for $ENV{SCRIPT_NAME}\n";	
	}

	$| = 1;
	$r->content_type ("text/html");
	$r->send_http_header("text/html");
	$r->print (<<EOF);
<HTML><HEAD><TITLE>Interchange server not running</TITLE></HEAD>
<BODY BGCOLOR="#FFFFFF">
<H3>We're sorry, the Interchange server was not running...</H3>
<P>
We are out of service or may be experiencing high system demand.
Please try again soon.

<H3>This is it:</H3>
<PRE>
$arg
$env
$ent
</PRE>

</BODY></HTML>
EOF

}

# Return this message to the browser when a system error occurs.
#
sub die_page {
  $r->print("Content-type: text/plain\r\n\r\n");
  $r->print("We are sorry, but the Interchange server is unavailable due to a\r\n");
  $r->print("system error.\r\n\r\n");
  $r->print(sprintf "%s: %s (%d)\r\n", $_[0], $!, $?);
  if($ERROR_ACTION =~ /not/i) {
	warn "ALERT: Interchange $ENV{SCRIPT_NAME} $_[0]: $! ($?)\n";
  }
  Apache::exit(1);
}


# Read the entity from stdin if present.

sub send_arguments {

	my $count = @ARGV;
	my $val = "arg $count\n";
	for(@ARGV) {
		$val .= length($_);
		$val .= " $_\n";
	}
	return $val;
}

sub send_environment () {
	my (@tmp) = keys %ENV;
	my $count = @tmp;
	my ($str);
	my $val = "";
	for(@tmp) {
		($count--, next) if defined $exclude_header{$_};
		$str = "$_=$ENV{$_}";
		$val .= length($str);
		$val .= " $str\n";
	}
	$val = "env $count\n$val";
	return $val;
}

sub send_entity {
	return '' unless defined $ENV{CONTENT_LENGTH};
	my $len = $ENV{CONTENT_LENGTH};
	return '' unless $len > 0;

	my $val = "entity\n";
	$val .= "$len ";
	return $val . $r->content() . "\n";
}

$arg = send_arguments();
$env = send_environment();
$ent = send_entity();

$SIG{PIPE} = sub { die_page("signal"); };
$SIG{ALRM} = sub { server_not_running(); exit 1; };

alarm $LINK_TIMEOUT;

my ($remote, $port, $iaddr, $paddr, $proto, $line);

$remote = $LINK_HOST;
$port   = $LINK_PORT;

if ($port =~ /\D/) { $port = getservbyname($port, 'tcp'); }

die_page("no port") unless $port;

$iaddr = inet_aton($remote);
$paddr = sockaddr_in($port,$iaddr);

$proto = getprotobyname('tcp');

local(*SOCK);
socket(SOCK, PF_INET, SOCK_STREAM, $proto)	or die "socket: $!\n";

my $ok;

do {
   $ok = connect(SOCK, $paddr);
} while ( ! defined $ok and $! =~ /interrupt/i);

my $def = defined $ok;
die "ok=$ok def: $def connect port=$LINK_PORT: $!\n" if ! $ok;

use vars qw/$in $l/;

select SOCK;
$| = 1;

alarm 0;
for ( $arg, $env, $ent, "end\n" ) {
	print $_;
}

while( <SOCK> ) {
	$r->print($_);
}

close (SOCK)								or die "close: $!\n";
Apache::exit();
