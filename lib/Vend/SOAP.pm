# SOAP.pm:  handle SOAP connections
#
# $Id: SOAP.pm,v 1.1.2.1 2001-02-22 19:59:54 heins Exp $
#
# Copyright (C) 1996-2001 Red Hat, Inc. <info@akopia.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

package Vend::SOAP;

require AutoLoader;

use Vend::Util;
use Vend::Interpolate;
use Vend::Order;
use Vend::Data;
use Vend::Session;
use HTTP::Response;
use HTTP::Headers;
use Vend::SOAP::Transport;

use strict;

use vars qw($VERSION @ISA $AUTOLOAD);
$VERSION = substr(q$Revision: 1.1.2.1 $, 10);
@ISA = qw/SOAP::Server/;

my %Allowed_tags;
my @Allowed_tags = qw/
	value
	scratch
	item_list
/;
for (@Allowed_tags) {
	$Allowed_tags{$_} = 1;
}

sub hello {
	my @args = @_;
	return "hello from the Vend::SOAP server, pid $$, world!\nreceived args:\n"
		. ::uneval(\@args);
}

sub add_item {
	my $self = shift;
	my $hash = shift;
	$Vend::SessionID = $hash->{session};
	$Vend::SessionName = session_name();
	if(defined $hash->{CGI}) {
		%CGI::values = %{$hash->{CGI}};
	}
eval {
::logDebug("before open_database");
	open_database();
::logDebug("before get_session");
	get_session();
	add_items($hash->{mv_order_item}, $hash->{mv_order_quantity});
::logDebug("before put_session");
	put_session();
::logDebug("before close_session");
	close_database();
::logDebug("before return");
};
	if($@) {
		logGlobal("SOAP died: $@");
	}
	return "hello from the Vend::SOAP server, pid $$, world!\nSession number is: $Vend::SessionName\nsession is:\n"
		. ::uneval($Vend::Session);
}


sub session {
	my $self = shift;
	my $hash = shift;
	$Vend::SessionID = $hash->{session};
	::get_session();
	::put_session();
	return $Vend::Session;
}

sub tag_soap {
	my ($method, $uri, $proxy, $opt) = @_;
	my @args;
	if($opt->{param}) {
		if (ref($opt->{param}) eq 'ARRAY') {
			@args = @{$opt->{param}};
		}
		elsif (ref($opt->{param}) eq 'HASH') {
			@args = %{$opt->{param}};
		}
		else {
			@args = $opt->{param};
		}
	}
	else {
		@args = $opt;
	}

	my $result;
#::logDebug("to method call, uri=$uri proxy=$proxy call=$method args=" . ::uneval(\@args));
	eval {
		$result = SOAP::Lite
					-> uri($uri)
					-> proxy($proxy)
					-> call( $method => @args )
					-> result;
	};
	if($@) {
		::logGlobal("error on SOAP call: %s", $@);
	}
::logDebug("after method call, uri=$uri proxy=$proxy call=$method result=$result");

	return $result;
}

sub AUTOLOAD {
    my $routine = $AUTOLOAD;
	my $self = shift;

    $routine =~ s/.*:://;
	die ::errmsg("Not allowed routine: %s", $routine) if ! $Allowed_tags{$routine};

	if(ref $self) {
		$Vend::SessionID = $self->{session};
	}
	my $hash;
	if(ref ($_[0]) eq 'HASH') {
		$hash = $_[0];
	}
	else {
		$hash = {};
	}


	$Vend::SessionID = $hash->{session} if ! $Vend::SessionID;
	open_database();
	::get_session();
	my $result;
	eval {
		if(ref($_[0]) =~ /HASH/) {
			@_ = Vend::Parse::resolve_args($routine, @_);
		}
		$result = Vend::Parse::do_tag($routine, @_);
	};
	::put_session;
	close_database;
	return $result;
}

1;
__END__

