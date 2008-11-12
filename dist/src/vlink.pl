#!/usr/bin/perl -wT

# vlink.pl: runs as a cgi program and passes request to Interchange server
#           via a UNIX socket

# $Id: vlink.pl,v 2.6 2008-11-12 04:15:22 jon Exp $
#
# Copyright (C) 2005-2008 Interchange Development Group, http://www.icdevgroup.org/
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
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

require 5.008_005;
use strict;
use Socket;
my $LINK_FILE    = '~@~INSTALLARCHLIB~@~/etc/socket';
#my $LINK_FILE    = '~_~LINK_FILE~_~';
my $LINK_TIMEOUT = 30;
#my $LINK_TIMEOUT = ~_~LINK_TIMEOUT~_~;
my $ERROR_ACTION = "-notify";

$ENV{PATH} = "/bin:/usr/bin";
$ENV{IFS} = " ";

# Return this message to the browser when the server is not running.
# Log an error log entry if set to notify

sub server_not_running {

	my $msg;

	if($ERROR_ACTION =~ /not/i) {
		warn "ALERT: Interchange server not running for $ENV{SCRIPT_NAME}\n";	
	}

	$| = 1;
	print <<EOF;
Content-type: text/html

<HTML><HEAD><TITLE>Interchange server not running</TITLE></HEAD>
<BODY BGCOLOR="#FFFFFF">
<H3>We're sorry, the Interchange server is unavailable...</H3>
<P>
We are out of service or may be experiencing high system demand.
Please try again soon.

</BODY></HTML>
EOF

}

# Return this message to the browser when a system error occurs.
#
sub die_page {
  printf("Content-type: text/plain\r\n\r\n");
  printf("We are sorry, but the Interchange server is unavailable due to a\r\n");
  printf("system error.\r\n\r\n");
  printf("%s: %s (%d)\r\n", $_[0], $!, $?);
  if($ERROR_ACTION =~ /not/i) {
	warn "ALERT: Interchange $ENV{SCRIPT_NAME} $_[0]: $! ($?)\n";
  }
  exit(1);
}


my $Entity = '';

# Read the entity from stdin if present.

sub get_entity {

  return '' unless defined $ENV{CONTENT_LENGTH};
  my $len = $ENV{CONTENT_LENGTH} || 0;
  return '' unless $len;

  my $check;

  # Can't hurt, helps Windows people
  binmode(STDIN);

  $check = read(STDIN, $Entity, $len);

  die_page("Entity wrong length")
    unless $check == $len;

  $Entity;

}


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
	my $val = "env $count\n";
	for(@tmp) {
		$str = "$_=$ENV{$_}";
		$val .= length($str);
		$val .= " $str\n";
	}
	return $val;
}

sub send_entity {
	return '' unless defined $ENV{CONTENT_LENGTH};
	my $len = $ENV{CONTENT_LENGTH};
	return '' unless $len > 0;

	my $val = "entity\n";
	$val .= "$len $Entity\n";
	return $val;
}

$SIG{PIPE} = sub { die_page("signal"); };
$SIG{ALRM} = sub { server_not_running(); exit 1; };

eval { alarm $LINK_TIMEOUT; };

socket(SOCK, PF_UNIX, SOCK_STREAM, 0)	or die "socket: $!\n";

my $ok;

do {
   $ok = connect(SOCK, sockaddr_un($LINK_FILE));
} while ( ! defined $ok and $! =~ /interrupt|such file or dir/i);

my $def = defined $ok;
die "ok=$ok def: $def connect: $!\n" if ! $ok;

get_entity();

select SOCK;
$| = 1;
select STDOUT;

print SOCK send_arguments();
print SOCK send_environment();
print SOCK send_entity();
print SOCK "end\n";


while(<SOCK>) {
	print;
}

close (SOCK)								or die "close: $!\n";
exit;

