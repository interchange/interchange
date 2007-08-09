# Vend::SOAP - Handle SOAP connections for Interchange
#
# $Id: SOAP.pm,v 2.18 2007-08-09 13:40:54 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 2000-2002 Red Hat, Inc.
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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

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
$VERSION = substr(q$Revision: 2.18 $, 10);
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

	if($opt->{trace_transport}) {
		if (exists $Vend::Cfg->{Sub}->{$opt->{trace_transport}}) {
			SOAP::Trace->import('transport' => $Vend::Cfg->{Sub}->{$opt->{trace_transport}});
		} else {
			::logError (qq{no such subroutine "$opt->{trace_transport}" for SOAP transport tracing});
		}
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
		::logError("error on SOAP call: %s", $@);
	}
#::logDebug("after method call, uri=$uri proxy=$proxy call=$method result=$result");

	$::Scratch->{$opt->{result}} = $result if $opt->{result};
	return '' if $opt->{init};
	return $result;
}

sub tag_soap_entity {
	my ($opt) = @_;
	my ($obj);

	if ($opt->{tree}) {
		my @values = map {tag_soap_entity($_)} @{$opt->{value}};
		$opt->{value} = \@values;
	}
	eval {$obj = new SOAP::Data (%$opt);};
	if ($@) {
		logError ("soap_entity failed: $@");
		return;
	}
	return $obj;
}

my %intrinsic = (local => sub {$CGI::remote_addr eq '127.0.0.1'},
				never => sub {return 0},
				always => sub {return 1});

sub soap_gate {
	my (@args, $status, $subref, $spath);

	# check first global control configuration which takes
	# precedence, then catalog control configuration
	for $subref ($Global::SOAP_Control,
				 $Vend::Cfg->{SOAP_Control}) {
		@args = @_;
				
		while (@args) {
			$spath = join('/', @args);
			pop(@args);
			next unless exists $subref->{$spath};

			if (ref($subref->{$spath}) eq 'CODE') {
				$status = $subref->{$spath}->($spath);
			} elsif ($subref->{$spath}) {
				$status = soap_control_intrinsic($subref->{$spath}, $spath);
			}

			# check found, done with loop
			last;
		}

		last unless $status;
	}
	
	die errmsg("Unauthorized access to '%s' method\n", join('/', @_))
		unless $status;

	return 1;
}

sub soap_control_intrinsic {
	my ($checklist, $action) = @_;
	my @checks = split /\s*;\s*/, $checklist;
	my $status = 1;

	for(@checks) {
		my ($check, @args) = split /:/, $_;
		my $sub = $intrinsic{$check} or return 0;
		
		unless( $sub->($action, @args) ) {
			$status = 0;
			last;
		}
	}
	return $status;
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

	soap_gate('Values');
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

	soap_gate('Scratch');
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
	
	soap_gate('Database', $name);

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
	my $sub;

	if($Tmp::Autoloaded++ > 100) {
		die "must be in endless loop, autoloaded $Tmp::Autoloaded times";
	}

	chdir $Vend::Cfg->{VendRoot} 
		or die "Couldn't change to $Vend::Cfg->{VendRoot}: $!\n";

	::open_database();
	open_soap_session();
#::logDebug("SOAP init_session done, session_id=$Vend::SessionID");

#::logDebug("session " . ::full_dump() );

    $routine =~ s/.*:://;
	
	if ($Vend::Cfg->{SOAP_Action}{$routine}) {
		soap_gate ('Action', $routine);
		$sub = $Vend::Cfg->{SOAP_Action}{$routine};
		Vend::Interpolate::init_calc();
		new Vend::Tags;
		new Vend::Parse;	# enable catalog usertags within SOAP actions
	} elsif (! $Allowed_tags{$routine}) {
		die ::errmsg("Not allowed routine: %s", $routine);
	} else {
		soap_gate ('Tag', $routine);
	}

	my $result;
	if (defined $sub) {
		eval {
			$result = $sub->(@_);
		};
	} else {
#::logDebug("do_tag $routine, args=" . ::uneval(\@_));
		eval {
			if(ref($_[0])) {
#::logDebug("resolving args");
				@_ = Vend::Parse::resolve_args($routine, @_);
			}
#::logDebug("do_tag $routine");
			$result = Vend::Parse::do_tag($routine, @_);
		};
	}
	
	my $error;
	if($@) {
		::logError("SOAP call for $routine failed: %s", $@);
		
		$error = SOAP::Server->make_fault($SOAP::Constants::FAULT_SERVER,
							   'Application error');
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

