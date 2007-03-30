# Vend::Accounting - Interchange payment processing routines
#
# $Id: Accounting.pm,v 2.3 2007-03-30 11:39:43 pajamian Exp $
#
# Copyright (C) 2002 Mike Heins, <mike@heins.net>
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

package Vend::Accounting;

$VERSION = substr(q$Revision: 2.3 $, 10);

use Vend::Util;
use LWP::UserAgent;
use Vend::Interpolate;
use strict;

use vars qw/$Have_LWP $Have_Net_SSLeay/;

my $acct_opt;

my %ignore_mv_accounting = (
	qw/
		gateway 1
	/
);

sub new {
	my $class = shift;
	return bless {}, $class;
}

sub account_param {
	my ($name, $value, $mode) = @_;
	my $opt;

	if($mode) {
		$opt = $Vend::Cfg->{Route_repository}{$mode} ||= {};
	}
	else {
		$opt = $acct_opt ||= {};
	}

	if($name =~ s/^mv_accounting_//i) {
		$name = lc $name;
	}

	if(defined $value) {
		return $acct_opt->{$name} = $value;
	}

	# Find if set in route or options
	return $opt->{$name}		if defined $opt->{$name};

	# "gateway" and possibly other future options
	return undef if $ignore_mv_accounting{$name};

	# Now check Variable space as last resort
	my $uname = "MV_ACCOUNTING_\U$name";

	return $::Variable->{$uname} if defined $::Variable->{$uname};
	return undef;
}

# Do remapping of payment variables submitted by user
# Can be changed/extended with remap/MV_PAYMENT_REMAP
sub map_fields {
	my ($vref, $cref) = (@_);
	$vref = $::Values		unless $vref;
	$cref = \%CGI::values	unless $cref;
	my @map = qw(

		address
		address1
		address2
		amount
		b_address
		b_address1
		b_address2
		b_city
		b_country
		b_fname
		b_lname
		b_name
		b_state
		b_zip
		check_account
		check_accttype
		check_checktype
		check_dl
		check_magstripe
		check_number
		check_routing
		check_transit
		city
		comment1
		comment2
		corpcard_type
		country
		cvv2
		email
		fname
		item_code
		item_desc
		lname
		mv_credit_card_exp_month
		mv_credit_card_exp_year
		mv_credit_card_number
		name
		origin_zip
		phone_day
		phone_night
		pin
		po_number
		salestax
		shipping
		state
		tax_duty
		tax_exempt
		tender
		zip
	);

	my %map = qw(
		comment                  giftnote
	);
	@map{@map} = @map;

	# Allow remapping of the variable names
	my $remap;
	if( $remap	= charge_param('remap') ) {
		$remap =~ s/^\s+//;
		$remap =~ s/\s+$//;
		my (%remap) = split /[\s=]+/, $remap;
		for (keys %remap) {
			$map{$_} = $remap{$_};
		}
	}

	my %actual;
	my $key;

	# pick out the right values, need alternate billing address
	# substitution
	foreach $key (keys %map) {
		$actual{$key} = $vref->{$map{$key}} || $cref->{$key}
			and next;
		my $secondary = $key;
		next unless $secondary =~ s/^b_//;
		$actual{$key} = $vref->{$map{$secondary}} || $cref->{$map{$secondary}};
	}
	$actual{name}		 = "$actual{fname} $actual{lname}"
		if $actual{lname};
	$actual{b_name}		 = "$actual{b_fname} $actual{b_lname}"
		if $actual{b_lname};
	if($actual{b_address1}) {
		$actual{b_address} = "$actual{b_address1}";
		$actual{b_address} .=  ", $actual{b_address2}"
			if $actual{b_address2};
	}
	if($actual{address1}) {
		$actual{address} = "$actual{address1}";
		$actual{address} .=  ", $actual{address2}"
			if $actual{address2};
	}

	return %actual;
}

sub account {
}

sub post_data {
	my ($opt, $query) = @_;

	unless ($Have_Net_SSLeay or $Have_LWP) {
		die "No Net::SSLeay or Crypt::SSLeay found.\n";
	}

	my $submit_url = $opt->{submit_url};
	my $server;
	my $port = $opt->{port} || 443;
	my $script;
	my $protocol = $opt->{protocol} || 'https';
	if($submit_url) {
		$server = $submit_url;
		$server =~ s{^https://}{}i;
		$server =~ s{(/.*)}{};
		$port = $1 if $server =~ s/:(\d+)$//;
		$script = $1;
	}
	elsif ($opt->{host}) {
		$server = $opt->{host};
		$script = $opt->{script};
		$script =~ s:^([^/]):/$1:;
		$submit_url = join "",
						$protocol,
						'://',
						$server,
						($port ? ":$port" : ''),
						$script,
						;
	}
	my %header = ( 'User-Agent' => "Vend::Payment (Interchange version $::VERSION)");
	if($opt->{extra_headers}) {
		for(keys %{$opt->{extra_headers}}) {
			$header{$_} = $opt->{extra_headers}{$_};
		}
	}

	my %result;
	if($Have_Net_SSLeay) {
#::logDebug("placing Net::SSLeay request: host=$server, port=$port, script=$script");
#::logDebug("values: " . uneval($query) );
		my ($page, $response, %reply_headers)
                = post_https(
					   $server, $port, $script,
                	   make_headers( %header ),
                       make_form(    %$query ),
					);
		my $header_string = '';

		for(keys %reply_headers) {
			$header_string .= "$_: $reply_headers{$_}\n";
		}
#::logDebug("received Net::SSLeay header: $header_string");
		$result{status_line} = $response;
		$result{status_line} =~ /^HTTP\S+\s+(\d+)/
			and $result{response_code} = $1;
		$result{header_string} = $header_string;
		$result{result_page} = $page;
	}
	else {
		my @query = %{$query};
		my $ua = new LWP::UserAgent;
		my $req = POST($submit_url, \@query, %header);
#::logDebug("placing LWP request: " . uneval_it($req) );
		my $resp = $ua->request($req);
		$result{status_line} = $resp->status_line();
		$result{status_line} =~ /(\d+)/
			and $result{response_code} = $1;
		$result{header_string} = $resp->as_string();
		$result{header_string} =~ s/\r?\n\r?\n.*//s;
#::logDebug("received LWP header: $header_string");
		$result{result_page} = $resp->content();
	}
#::logDebug("returning thing: " . uneval_it(\%result) );
	return \%result;
}

1;
__END__
