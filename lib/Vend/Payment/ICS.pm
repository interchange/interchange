# Vend::Payment::ICS - Interchange Cybersource ICS Support
#
# $Id: ICS.pm,v 1.2 2007-03-30 11:39:52 pajamian Exp $
#
# Copyright (C) 2005 End Point Corporation
#
# Written by Sonny Cook <sonny@endpoint.com>
# based on code by Mike Heins <mike@perusion.com>

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

package Vend::Payment::ICS;

=head1 Interchange ICS Support

Vend::Payment::ICS $Revision: 1.2 $

=head1 SYNOPSIS

=head1 PREREQUISITES

ICS Library
ICS.pm

=head1 DESCRIPTION

In interchange.cfg:

Require module Vend::Payment::ICS


In catalog.cfg:

Variable  MV_PAYMENT_MODE  ICS

Route  ICS  server_host          ics2test.ic3.com
Route  ICS  server_port          80
Route  ICS  path                 /path/to/lib/CyberSource/SDK
Route  ICS  merchant_id          your_merchant_id
Route  ICS  apps                 ics_auth,ics_auth_reversal,ics_bill,ics_credit
Route  ICS  timeout              20
Route  ICS  merchant_descriptor	 "test merchant"
Route  ICS  merchant_descriptor_contact  "phone number"


You must first install CyberSource's ICS.pm and put your "keys" directory in the
location pointed to by the "path" parameter. Obviously you must have a merchant
account set up.

=head1 AUTHOR

Sonny Cook <sonny@endpoint.com>

=cut

package Vend::Payment;
use strict;

# Requires CyberSource ICS perl SDK
use ICS qw(ics_send ics_print);

sub ICS {
#::logDebug("ICS called--in the begining");
	my ($opt) = @_;
	$opt->{order_number} ||= $opt->{order_id};

#::logDebug("ICS opt hash: %s", ::uneval($opt));

    my %type_map = qw(
   		sale          auth_bill
		auth          auth
		authorize     auth
		void          auth_reversal
		settle        bill
		credit        credit
		mauthcapture  auth_bill
		mauthonly     auth
		mauthdelay    auth
		mauthreturn   credit
		S             auth_bill
		C             credit
		D             bill
		V             auth_reversal
		A             auth
	);

	my %inv_trans_map = qw(
		auth          A
		auth_bill     S
		credit        C
		auth_reversal V
		bill          D
	);

    my %app_map = (
		auth			=> [qw/ ics_dav ics_export ics_score ics_auth /],
		auth_bill		=> [qw/ ics_dav ics_export ics_score ics_auth ics_bill/],
		auth_reversal	=> [qw/ ics_auth_reversal /],
		bill			=> [qw/ ics_bill /],
		credit			=> [qw/ ics_credit /],
	);
					 
    my $transtype = $opt->{transaction} || charge_param('transaction') || 
		$opt->{cyber_mode} || charge_param('cyber_mode') || 'auth';

#::logDebug("tansaction type: $transtype");

	$transtype = $type_map{$transtype}
		or return (
			MStatus => 'failure-hard',
			MErrMsg => errmsg('Unrecognized transaction: %s', $transtype),
		);

	# get list of applications to use
	my @apps;
	for (@{$app_map{$transtype}}) {
		my $a = $_;
		push @apps, grep lc $a eq lc $_, split /[,| ]\s*/, $opt->{apps};
	}
#::logDebug ("Applications: " . uneval \@apps);

	# ics_auth_required
  	my %required_map = (
		all               => [ qw(
								merchant_id
								merchant_ref_number
								ics_applications
								server_host
								server_port
								) ],
		ics_auth          => [ qw(
								bill_address1
								bill_city
								bill_country
								bill_state
								bill_zip
								currency
								customer_cc_expmo
								customer_cc_expyr
								customer_cc_number
								customer_email
								customer_firstname
								customer_lastname
								merchant_ref_number
								ship_to_address1
								ship_to_city
								ship_to_country
								ship_to_state
								ship_to_zip
								) ],
		ics_auth_reversal => [ qw(
								auth_request_id
								currency
								merchant_ref_number
								) ],
		ics_bill          => [ qw(
								auth_request_id
								) ],
		ics_credit        => [ qw(
								bill_address1
								bill_city
								bill_country
								bill_state
								bill_zip
								currency
								customer_cc_expmo
								customer_cc_expyr
								customer_cc_number
								customer_email
								customer_firstname
								customer_lastname
								merchant_ref_number
								) ],
		ics_dav           => [],
		ics_export        => [],
		ics_score         => [],
	);
	
    my %exempt_map = (
		billing_intl => [ qw(
							bill_address1
							bill_city
							bill_country
							bill_state
							bill_zip
							) ],
		shipping_intl => [ qw(
							ship_to_address1
							ship_to_city
							ship_to_country
							ship_to_state
							ship_to_zip
							) ],
	);

	# These fields are not necessarily optional on our end,
	# they are just optional on the ICS end.
	my %optional_map = (
		all               => [ qw( timeout ) ],
		ics_auth          => [ qw(
								bill_address2 
								ship_to_address2
								customer_cc_cv_number 
								ignore_avs
								ignore_bad_cv
								merchant_descriptor
								merchant_descriptor_contact
								) ],
		ics_auth_reversal => [],
		ics_bill          => [ qw(
								merchant_descriptor
								merchant_descriptor_contact
								) ],
		ics_credit        => [ qw(
								merchant_descriptor
								merchant_descriptor_contact
								) ],
		ics_dav           => [],
		ics_export        => [],
		ics_score         => [],
	);

	my %default_map = qw(
		timeout       10
		ignore_avs    yes
		ignore_bad_cv yes
		currency      usd
	);

  	my %actual_map = qw(
		bill_address1         b_address1
		bill_address2         b_address2
		bill_city             b_city
		bill_country          b_country
		bill_state            b_state
		bill_zip              b_zip
		customer_cc_expmo     mv_credit_card_exp_month
		customer_cc_expyr     mv_credit_card_exp_year
		customer_cc_number    mv_credit_card_number
		customer_cc_cv_number mv_credit_card_cvv2
		customer_email        email
		customer_firstname    b_fname
		customer_lastname     b_lname
		ship_to_address1      address1
		ship_to_address2      address2
		ship_to_city          city
		ship_to_country       country
		ship_to_state         state
		ship_to_zip           zip
	);

	my %opt_map = qw (
		merchant_ref_number order_number
		auth_request_id     origid
	);

	my %vital_error_map = (
		'01' => "Authorization has been declined.",
		'02' => "Authorization has been declined.",
		'03' => "We are experiencing system difficulties. Please try again later.",
		'04' => "Authorization has been declined.",
		'05' => "Authorization has been declined.",
		'07' => "Authorization has been declined.",
		'12' => "We are experiencing system difficulties. Please try again later.",
		'13' => "Invalid amount.",
		'14' => "Invalid card number.",
		'15' => "Invalid Card Number.",
		'19' => "Authorization has been declined.",
		'39' => "Invalid card number.",
		'41' => "Authorization has been declined.",
		'43' => "Authorization has been declined.",
		'51' => "Insufficient funds.",
		'52' => "Invalid card number.",
		'53' => "Invalid card number.",
		'54' => "Card is expired.",
		'55' => "Incorrect PIN.",
		'57' => "Authorization has been declined.",
		'58' => "Authorization has been declined.",
		'61' => "Amount exceeds withdrawal limit.",
		'62' => "Authorization has been declined.",
		'63' => "Authorization has been declined.",
		'65' => "Activity limit exceeded.",
		'75' => "PIN tries exceeded.",
		'78' => "Invalid card number.",
		'79' => "We had difficulty processing your transaction. Please call customer service to complete order.",
		'80' => "Invalid expiration date.",
		'82' => "Cashback limit exceeded.",
		'83' => "Can not verify PIN.",
		'86' => "Can not verify PIN.",
		'92' => "We had difficulty processing your transaction. Please call customer service to complete order.",
		'93' => "Authorization has been declined.",
		'EA' => "We had difficulty processing your transaction. Please call customer service to complete order.",
		'EB' => "We had difficulty processing your transaction. Please call customer service to complete order.",
		'EC' => "We had difficulty processing your transaction. Please call customer service to complete order.",
		'N3' => "Cashback service not available.",
		'N4' => "Amount exceeds issuer withdrawal limit.",
		'N7' => "Invalid Card Security Code.",
	);

	# Special Cases
	$required_map{ics_bill} = [] if $transtype eq 'auth_bill';

  	my %actual = $opt->{actual} ? %{$opt->{actual}} : map_actual();

	my @required_keys = (@{$required_map{all}}, @{$optional_map{all}});
	push @required_keys, @{$required_map{$_}} for @apps;

	my @optional_keys;
	push @optional_keys, @{$optional_map{$_}} for @apps;

	# Build Request
	my @request_keys = (@required_keys, @optional_keys);
  	my %request = map { $_ => $actual{$actual_map{$_}} }
		grep defined $actual{$actual_map{$_}}, @request_keys;

	$request{$_} = $opt->{$_} for grep defined $opt->{$_}, @request_keys;

	$request{$_} = $opt->{$opt_map{$_}} for grep defined $opt->{$opt_map{$_}}, @request_keys;

  	# Uses the {currency} -> MV_PAYMENT_CURRENCY options if set
  	$request{currency} = charge_param('currency')
		|| ($Vend::Cfg->{Locale} && $Vend::Cfg->{Locale}{currency_code})
		|| 'usd';

	# Add defaults
	$request{$_} ||= $default_map{$_} for grep defined $default_map{$_}, @request_keys;

	# Set Applications Field
	$request{ics_applications} = join ',', @apps;

    # build exempt keys hash
	my %exempt_keys;
    for (keys %exempt_map) {
		## these keys apply only if we are shipping outside the 
		## US or CA
		next if $_ eq 'billing_intl'
	   		and (
				lc $request{bill_country} eq 'us'
				or lc $request{bill_country} eq 'ca'
			);

		next if $_ eq 'shipping_intl'
			and (
				lc $request{ship_to_country} eq 'us'
				or lc $request{ship_to_country} eq 'ca'
			);

		$exempt_keys{$_}++ for @{$exempt_map{$_}};
    }

	# make sure that we have ALL required fields filled
	# exempt fields can be present, but are not required
    for (@required_keys) {
		if (! defined $request{$_} && ! $exempt_keys{$_}) {
			return (
				MStatus => 'failure-hard',
				MErrMsg => errmsg("Missing value for >$_< field"),
			);
		}
	}

	# Set ENV for ICSPATH; this is the path to the SSL certs
    $ENV{ICSPATH} = $opt->{path};

    # Build Offers
  	$request{offer0} = "offerid:0^amount:" . $opt->{total_cost};

#::logDebug("ICS Sending Request...\n" . uneval \%request);
  	my %resp = ics_send(%request);
#::logDebug("ICS Response: " . uneval \%resp);    

	# Handle failure
	my $status = $resp{ics_rcode} == 1 ? 'success' : 'failed';
	if ($status eq 'failed') {
		my $code = $resp{auth_auth_response};
		my $msg = $vital_error_map{$code} || $resp{ics_rmsg};
		$msg = "($code)  " . $msg if $code;
		return (
			MStatus => 'failure-hard',
			MErrMsg => errmsg($msg),
		);
	}

	my ($avs_addr, $avs_zip) = handle_avs($resp{auth_auth_avs});
    my $cv = handle_cv($resp{auth_cv_result});

	my %result = (
		MStatus    => $status,
		'order-id' => $resp{request_id},
		transtype  => $inv_trans_map{$transtype}, 
		ORIGID     => $resp{request_id},
		PNREF      => $resp{request_id},
		AVSADDR    => $avs_addr,
		AVSZIP     => $avs_zip,
		CVV2MATCH  => $cv,
	);
									
	return %result;
}

# Results of address verification.
# This field will contain one of the following values:

# A: Street number matches, but 5-digit ZIP code and 9-digit ZIP code do not match.
# B: Street address match for non-U.S. AVS transaction. Postal code not verified.
# C: Street address and postal code not verified for non-U.S. AVS transaction.
# D: Street address and postal code match for non-U.S. AVS transaction.
# E: AVS data is invalid.
# G: Non-U.S. card issuing bank does not support AVS.
# I: Address information not verified for non-U.S. AVS transaction.
# M: Street address and postal code match for non-U.S. AVS transaction.
# N: Street number, 5-digit ZIP code, and 9-digit ZIP code do not match.
# P: Postal code match for non-U.S. AVS transaction. Street address not verified.
# R: System unavailable.
# S: Issuing bank does not support AVS.
# U: Address information unavailable. Returned if non-U.S. AVS is not available or if the AVS in a U.S. bank is not functioning properly.
# W: Street number does not match, but 5-digit ZIP code and 9-digit ZIP code match.
# X: Exact match. Street number, 5-digit ZIP code, and 9-digit ZIP code match.
# Y: Both street number and 5-digit ZIP code match.
# Z: 5-digit ZIP code matches.
# 1: CyberSource does not support AVS for this processor or card type.
# 2: The processor returned an unrecognized value for the AVS response.

sub handle_avs {
	my $c = shift;
	# returns (address, zip)

	# D,M,X,Y
	return ('Y', 'Y') if $c eq 'D' || $c eq 'M' || $c eq 'X' || $c eq 'Y';

	# A
	return ('Y', 'N') if $c eq 'A';

	# W
	return ('N', 'Y') if $c eq 'W';

  	# P,Z
  	return ('', 'Y') if $c eq 'P' || $c eq 'Z';

  	# B
  	return ('Y', '') if $c eq 'B';

	# N
	return ('N', 'N') if $c eq 'N';

  	# C,E,G,I,R,S,U,1,2
  	return ('', '');
}

# Result of processing the card verification number.
# This field will contain one of the following values:

# M: Card verification number matched.
# N: Card verification number not matched.
# P: Card verification number not processed.
# S: Card verification number is on the card but was not included in the request.
# U: Card verification is not supported by the issuing bank.
# X: Card verification is not supported by the card association.
# <space>: Deprecated. Ignore this value.
# 1: CyberSource does not support card verification for this processor or card type.
# 2: The processor returned an unrecognized value for the card verification response.
# 3: The processor did not return a card verification result code.

sub handle_cv {
  	my $c = shift;
  	return 'Y' if $c eq 'M';
  	return 'N' if $c eq 'N';
  	return '';
}

package Vend::Payment::ICS;

1;
