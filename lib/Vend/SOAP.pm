# Vend::SOAP - Handle SOAP connections for Interchange
#
# $Id: SOAP.pm,v 2.3.2.1 2003-01-25 22:21:28 racke Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. <interchange@redhat.com>
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
use HTTP::Response;
use HTTP::Headers;
use Vend::SOAP::Transport;
require SOAP::Transport::IO;
require SOAP::Transport::HTTP;
use strict;

use vars qw($VERSION @ISA $AUTOLOAD);
$VERSION = substr(q$Revision: 2.3.2.1 $, 10);
@ISA = qw/SOAP::Server/;

my %Allowed_tags;
my @Allowed_tags = qw/
accessories
area
cart
counter
currency
data
description
discount
dump
error
export
field
filter
fly_list
fly_tax
handling
import
index
input_filter
item_list
label
log
loop
mail
nitems
onfly
options
order
page
price
process
profile
query
record
salestax
scratch
scratchd
selected
set
setlocale
shipping
shipping_desc
subtotal
time
total_cost
tree
update
userdb
value
value_extended
/;

for (@Allowed_tags) {
	$Allowed_tags{$_} = 1;
}

sub hello {
	my $self = shift;
	my @args = @_;
	return "hello from the Vend::SOAP server, pid $$, world!\nreceived args:\n"
		. uneval(\@args);
}

sub soaptest {
	my $self = shift;
	my @args = @_;
	return @args;
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
		if(! $method ) {
			$result = SOAP::Lite
					-> uri($uri)
					-> proxy($proxy)
					-> call ('init');
		}
		elsif(ref $opt->{object}) {
			$result = $opt->{object}
					-> uri($uri)
					-> proxy($proxy)
					-> call( $method => @args )
					-> result;
		}
		else {
			$result = SOAP::Lite
					-> uri($uri)
					-> proxy($proxy)
					-> call( $method => @args )
					-> result;
		}
	};
	if($@) {
		::logGlobal("error on SOAP call: %s", $@);
	}
#::logDebug("after method call, uri=$uri proxy=$proxy call=$method result=$result");

	return '' if $opt->{init};
	return $result;
}

# This is used to check the session name. If there is some reason
# the session is retired, the returned ID will be different from the
# passed ID and the client can cope.
#
# This variant returns the full SessionName so that multiple hosts
# can use the same ID.
sub session_name {
	my $self = shift;
	my $class = ref($self) || $self;
	my $sid = shift;

	if($sid) {
#::logDebug("looking to assign session $sid, sessionID=$Vend::SessionID cookiehost=$CGI::cookiehost");
		$Vend::SessionID = $sid;
		$Vend::SessionID =~ s/:(.*)//
			and $CGI::cookiehost = $1;
	}

	open_soap_session();
	close_soap_session();
	
#::logDebug("actual session name $Vend::SessionName");
	return $Vend::SessionName;
}

# This is used to check the session name. If there is some reason
# the session is retired, the returned ID will be different from the
# passed ID and the client can cope.
#
# This variant returns only the SessionID for better security in single-host
# environments.
sub session_id {
	my $self = shift;
	my $class = ref($self) || $self;
	my $sid = shift;

	if($sid) {
#::logDebug("looking to assign session id $sid");
		$Vend::SessionID = $sid;
	}

	open_soap_session();
	close_soap_session();

#::logDebug("actual session name $Vend::SessionID");
	return $Vend::SessionID;
}

sub Values {
	shift;
	open_soap_session();
	my $putref;
	my $ref = $::Values ||= {};
#::logDebug("ref from session is " . ::uneval($ref));
	if($putref = shift) {
		%{$ref} = %{$putref};
	}
	close_soap_session();
#::logDebug("ref from session is now " . ::uneval($ref));
	return $ref;
}

sub Session {
	shift;
	open_soap_session();
	my $putref;
	my $ref = $Vend::Session;
	if($putref = shift) {
		if (! ref($ref)) {
			Vend::Session::init_session();
			$ref = $Vend::Session;
		}
		%{$ref} = %{$putref};
	}
	close_soap_session();
	return $ref;
}

sub Scratch {
	shift;
	open_soap_session();
	my $putref;
	my $ref = $Vend::Session->{scratch};
	if($putref = shift) {
		$ref = $Vend::Session->{scratch} = {}
			if ! ref($ref);
		%{$ref} = %{$putref};
	}
	close_soap_session();
	return $ref;
}

sub Database {
	shift;
	my $name = shift;
	my $ref = $Vend::Cfg->{Database};
	return $ref->{$name} if $name;
	return $ref;
}

sub open_soap_session {
#::logDebug("opening session $Vend::SessionID");
	::get_session($Vend::SessionID);
#::logDebug("actual session $Vend::SessionID");
	return $Vend::SessionID;
}

sub close_soap_session {
#::logDebug("closing session $Vend::SessionID");
	::put_session();
	::close_session();
	undef $Vend::Session;
	undef $Vend::SessionOpen;
}

sub AUTOLOAD {
    my $routine = $AUTOLOAD;
#::logDebug("SOAP autoload called, routine=$routine, args=" . ::uneval(\@_));
	my $class = shift;

	if($Tmp::Autoloaded++ > 100) {
		die "must be in endless loop, autoloaded $Tmp::Autoloaded times";
	}

	::open_database();
	open_soap_session();
#::logDebug("SOAP init_session done, session_id=$Vend::SessionID");

#::logDebug("session " . ::full_dump() );

    $routine =~ s/.*:://;
	die ::errmsg("Not allowed routine: %s", $routine) if ! $Allowed_tags{$routine};

	my $result;
#::logDebug("do_tag $routine, args=" . ::uneval(\@_));
	eval {
		if(ref($_[0])) {
#::logDebug("resolving args");
			@_ = Vend::Parse::resolve_args($routine, @_);
		}
#::logDebug("do_tag $routine");
		$result = Vend::Parse::do_tag($routine, @_);
	};

	my $error;
	if($@) {
		$error = errmsg("SOAP tag call failed: %s", $@);
	}
#::logDebug("session " . ::full_dump() );

	close_soap_session();
	::close_database();

	die $error if $error;

#::logDebug("session " . ::full_dump() );
	return $result;
}

1;
__END__

