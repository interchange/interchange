# Vend::Payment::Skipjack - Interchange Skipjack support
#
# $Id: Skipjack.pm,v 2.11 2009-03-16 19:34:01 jon Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1999-2002 Red Hat, Inc.
#
# Written by Cameron Prince and Mark Johnson, based on code by Mike Heins

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

package Vend::Payment::Skipjack;

=head1 NAME

Vend::Payment::Skipjack - Interchange Skipjack Support

=head1 SYNOPSIS

    &charge=skipjack

        or

    [charge mode=skipjack param1=value1 param2=value2]

=head1 PREREQUISITES

  Net::SSLeay
 
    or
  
  LWP::UserAgent and Crypt::SSLeay

Only one of these need be present and working.

=head1 DESCRIPTION

The Vend::Payment::Skipjack module implements the skipjack() routine for using
Skipjack IC payment services with Interchange. It is compatible on a call level
with the other Interchange payment modules.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::Skipjack

This I<must> be in interchange.cfg or a file included from it.

NOTE: Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<skipjack>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  skipjack

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge mode=skipjack id=YourSkipjackID]

or

    Route skipjack id YourSkipjackID

or with only Skipjack as a payment provider

    Variable MV_PAYMENT_ID      YourskipjackID

A fully valid catalog.cfg entry to work with the standard demo would be:

    Variable MV_PAYMENT_MODE      skipjack
    Route skipjack id             YourSkipjackID
    Route skipjack vendor         YourSkipjackVendor

The active settings are:

=over 4

=item id

Your account ID number, supplied by Skipjack when you sign up. Use the
supplied HTML Serial Numbers (Nova or Vital) while testing in development 
mode. Global parameter is MV_PAYMENT_ID.

=item vendor

The developer ID of the system which interfaces with Skipjack.
Global parameter is MV_PAYMENT_VENDOR.

=item transaction

The type of transaction to be run. Valid values are:

    Interchange         Skipjack
    ----------------    -----------------
	sale                sale
	recurring           recurring

Default is C<sale>.

If you wish to do a recurring charge, you will have to ensure that the
following Interchange values are set properly:

	Interchange variable     Skipjack variable
	--------------------     -----------------
	recurring_item           rtItemNumber
	recurring_desc           rtItemDescription
	recurring_start_date     rtStartingDate
	recurring_frequency      rtFrequency
	recurring_transactions   rtTotalTransactions
	recurring_comment        rtComment

=item test

If you set the C<test> parameter, Interchange will remap some values and
the URL for the transaction to point to the Skipjack test server.
It will return a valid transaction if all is working.

=item generate_error

To generate errors in test mode only, set the parameter C<generate_error>
to one of the following values (error it generates in parenthesese):

	number   (invalid credit card number)
	avs      (will succeed, but generate AVS message)
	exp      (expired card)
	id       (invalid Skipjack account?)
	vendor   (invalid vendor?)

=back

The following should rarely be used, as the supplied defaults are
usually correct.

=over 4

=item remap

This remaps the form variable names to the ones needed by Skipjack. See
the C<Payment Settings> heading in the Interchange documentation for use.

=item submit_url

The Skipjack URL to submit to. Default is:

	https://www.skipjackic.com/scripts/evolvcc.dll?Authorize

Add the following to catalog.cfg while in development mode:

	Route skipjack submit_url 'https://developer.skipjackic.com/scripts/evolvcc.dll?Authorize'

=back

=head2 Troubleshooting

Try the instructions above, then enable test mode:

	Route skipjack  test           1

A test order should complete.

Then set a generate error

	Route skipjack  test           1
	Route skipjack  generate_error number

and try a sale. The sale should be denied, and the reason should
be in [data session payment_error].

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::Skipjack

=item *

Make sure either Net::SSLeay or Crypt::SSLeay and LWP::UserAgent are installed
and working. You can test to see whether your Perl thinks they are:

    perl -MNet::SSLeay -e 'print "It works\n"'

or

    perl -MLWP::UserAgent -MCrypt::SSLeay -e 'print "It works\n"'

If either one prints "It works." and returns to the prompt you should be OK
(presuming they are in working order otherwise).

=item *

Check the error logs, both catalog and global.

=item *

Make sure you set your account ID properly.  

=item *

Try an order, then put this code in a page:

    <XMP>
    [calc]
        my $string = $Tag->uneval( { ref => $Session->{payment_result} });
        $string =~ s/{/{\n/;
        $string =~ s/,/,\n/g;
        return $string;
    [/calc]
    </XMP>

That should show what happened.

=item *

If all else fails, consultants are available to help with integration for a fee.
See http://www.icdevgroup.org/

=back

=head1 BUGS

There is actually nothing *in* Vend::Payment::Skipjack. It changes packages
to Vend::Payment and places things there.

=head1 AUTHORS

Originally developed by New York Connect Net (http://nyct.net)
Michael Bacarella <mbac@nyct.net>

Modified for GetCareer.com by Slipstream.com by Troy Davis <troy@slipstream.com>

LWP/Crypt::SSLeay interface code by Matthew Schick,
<mschick@brightredproductions.com>.

Interchange implementation by Mike Heins.

=cut

BEGIN {

	my $selected;
	eval {
		package Vend::Payment;
		require Net::SSLeay;
		import Net::SSLeay qw(post_https make_form make_headers);
		$selected = "Net::SSLeay";
	};

	$Vend::Payment::Have_Net_SSLeay = 1 unless $@;

	unless ($Vend::Payment::Have_Net_SSLeay) {

		eval {
			package Vend::Payment;
			require LWP::UserAgent;
			require HTTP::Request::Common;
			require Crypt::SSLeay;
			import HTTP::Request::Common qw(POST);
			$selected = "LWP and Crypt::SSLeay";
		};

		$Vend::Payment::Have_LWP = 1 unless $@;

	}

	unless ($Vend::Payment::Have_Net_SSLeay or $Vend::Payment::Have_LWP) {
		die __PACKAGE__ . " requires Net::SSLeay or Crypt::SSLeay";
	}

	::logGlobal("%s payment module initialized, using %s", __PACKAGE__, $selected)
		unless $Vend::Quiet or ! $Global::VendRoot;

}

package Vend::Payment;

use vars qw/%SJ_ERRORS %SJ_AVS_CODES %SJ_RT_FREQ %SJ_RC_ERRORS/;
use vars qw/$Have_LWP $Have_Net_SSLeay/;

%SJ_ERRORS = (
        '-1'    =>      'Invalid length (-1)',
        '-35'   =>      'Invalid credit card number (-35)',
        '-37'   =>      'Failed communication (-37)',
        '-39'   =>      'Serial number is too short (-39)',
        '-51'   =>      'The zip code is invalid',
        '-52'   =>      'The shipto zip code is invalid',
        '-53'   =>      'Length of expiration date (-53)',
        '-54'   =>      'Length of account number date (-54)',
        '-55'   =>      'Length of street address (-55)',
        '-56'   =>      'Length of shipto street address (-56)',
        '-57'   =>      'Length of transaction amount (-57)',
        '-58'   =>      'Length of name (-58)',
        '-59'   =>      'Length of location (-59)',
        '-60'   =>      'Length of state (-60)',
        '-61'   =>      'Length of shipto state (-61)',
        '-62'   =>      'Length of order string (-62)',
        '-64'   =>      'Invalid phone number (-64)',
        '-65'	=>		'Empty name (-65)',
        '-66'   =>      'Empty email (-66)',
        '-67'   =>      'Empty street address (-66)',
        '-68'   =>      'Empty city (-68)',
        '-69'   =>      'Empty state (-69)',
        '-70'   =>      'Empty zip code (-70)',
        '-71'   =>      'Empty order number (-71)',
        '-72'   =>      'Empty account number (-72)',
        '-73'   =>      'Empty expiration month (-73)',
        '-74'   =>      'Empty expiration year (-74)',
        '-75'   =>      'Empty serial number (-75)',
        '-76'   =>      'Empty transaction amount (-76)',
        '-79'   =>      'Length of customer name (-79)',
        '-80'   =>      'Length of shipto customer name (-80)',
        '-81'   =>      'Length of customer location (-81)',
        '-82'   =>      'Length of customer state (-82)',
        '-83'   =>      'Length of shipto phone (-83)',
        '-84'   =>      'Pos Error duplicate ordernumber (-84)',
        '-91'   =>      'Pos Error CVV2 (-91)',
        '-92'   =>      'Pos Error Approval Code (-92)',
        '-93'   =>      'Pos Error Blind Credits Not Allowed (-93)',
        '-94'   =>      'Pos Error Blind Credits Failed (-94)',
        '-95'   =>      'Pos Error Voice Authorizations Not Allowed (-95)',
);

%SJ_AVS_CODES = (
	'X' => 'Exact match, 9 digit zip',
	'Y' => 'Exact match, 5 digit zip',
	'A' => 'Address match only',
	'W' => '9 digit match only',
	'Z' => '5 digit match only',
	'N' => 'No address or zip match',
	'U' => 'Address unavailable',
	'R' => 'Issuer system unavailable',
	'E' => 'Not a mail/phone order',
	'S' => 'Service not supported'
);

%SJ_RT_FREQ = (		# Logic used for the frequency of recurring transactions
		'Weekly' => '0',			# Starting Date + 7 Days
		'Biweekly' => '1',			# Starting Date + 14 Days
		'Twice Monthly' => '2',		# Starting Date + 15 Days
		'Monthly' => '3',			# Every month
		'Every Four Weeks' => '4',	# Every fourth week
		'Bimonthly' => '5',			# Every other month
		'Quarterly' => '6',			# Every third month
		'Biannually' => '7',		# Semiannually / Twice per year
		'Annually' => '8', 			# Once a year
		'0' =>	'0',
		'1'	=>	'1',
		'2'	=>	'2',
		'3'	=>	'3',
		'4'	=>	'4',
		'5'	=>	'5',
		'6'	=>	'6',
		'7'	=>	'7',
		'8'	=>	'8'
);

%SJ_RC_ERRORS = (
		'1'		=>	'CALL FAILED (1)',
		'-1'	=>	'INVALID COMMAND (-1)',
		'-2'	=>	'PARAMETER MISSING (-2)',
		'-3'	=>	'FAILED RETRIEVING RESPONSE (-3)',
		'-4'	=>	'INVALID STATUS (-4)',
		'-5'	=>	'FAILED READING SECURITY FLAGS (-5)',
		'-6'	=>	'DEVELOPER SERIAL NUMBER NOT FOUND (-6)',
		'-7'	=>	'INVALID SERIAL NUMBER (-7)',
		'-8'	=>	'EXPIRATION YEAR IS NOT FOUR CHARECTERS (-8)',
		'-9'	=>	'CREDIT CARD EXPIRED (-9)',
		'-10'	=>	'INVALID STARTING DATE (-10)',
		'-11'	=>	'FAILED ADDING RECURRING PAYMENT (-11)',
		'-12'	=>	'INVALID FREQUENCY (-12)'
);

sub sj_test_values {
	my ($inopt, $inval) = @_;
	my $opt = {
		id         => '000658076426',
		submit_url =>
			'https://developer.skipjackic.com/scripts/evolvcc.dll?Authorize',
		vendor     => '111222333444',
	};
	my $val = {
		mv_credit_card_number     => '4445999922225',
		mv_credit_card_cvv2       => '999',
		mv_credit_card_exp_month  => '09',
		mv_credit_card_exp_year   => '02',
		b_address                 => '8320 Rocky Road',
		b_zip                     => '85284',
	};

	my $gen;
	if($inopt and $gen = $inopt->{generate_error}) {
		$opt->{id} = '1111000011111' if $gen eq /\bid\b/i;
		$opt->{vendor} = '1111000011111' if $gen =~ /vendor/i;
		$val->{mv_credit_card_number} = '4111111111111112' if $gen =~ /number/i;
		$val->{b_zip} = '45056' if $gen =~ /avs/i;
		$val->{mv_credit_card_exp_year} = '00' if $gen =~ /exp/i;
	}

	if($inopt) {
		for (keys %$opt) {
			$inopt->{$_} = $opt->{$_};
		}
	}
	if($inval) {
		for (keys %$val) {
			$inval->{$_} = $val->{$_};
		}
	}
	return ($opt, $val);
}

sub skipjack {
	my ($opt, $amount) = @_;

	my $user = $opt->{id} || charge_param('id');

	my %actual;
	if($opt->{actual}) {
		%actual = %{$opt->{actual}};
	}
	else {
		%actual = map_actual();
	}

#::logDebug("Mapping: " . ::uneval(%actual));

	if($opt->{test} || charge_param('test')) {
		sj_test_values($opt, \%actual);
	}

	my $ccem = $actual{mv_credit_card_exp_month};
	$ccem =~ s/\D//g;
	$ccem =~ s/^0+//;
	$ccem = sprintf('%02d', $ccem);

	my $ccey = $actual{mv_credit_card_exp_year};
	$ccey += 2000 unless $ccem =~ /\d{4}/;

	$actual{mv_credit_card_number} =~ s/\D//g;
	$actual{phone_day} =~ s/\D//g;

	my $precision = $opt->{precision} || charge_param('precision') || 2;

	$amount = $opt->{total_cost} || undef;

	$opt->{transaction} ||= 'sale';
	my $transtype = $opt->{transaction};

	# Skipjack doesn't do transaction types?
	my %type_map = (
	);
	
	if (defined $type_map{$transtype}) {
        $transtype = $type_map{$transtype};
    }

    if(! $amount) {
			$amount = Vend::Interpolate::total_cost();
			$amount = Vend::Util::round_to_frac_digits($amount,$precision);
    }

	my %values;
	if($transtype eq 'sale') {
		%values = (
		 	Sjname => $actual{b_name},
			Email => $actual{email},
			Streetaddress => $actual{b_address},
			City => $actual{b_city},
			State => $actual{b_state},
			Zipcode => $actual{b_zip},
			Ordernumber => $opt->{order_id},
			Accountnumber => $actual{mv_credit_card_number},
			Month => $ccem,
			Year => $ccey,
			Serialnumber => $user,
			Transactionamount => $amount,
			Orderstring => "0001~Generic Order String~$amount~1~N~||",
			Shiptophone => $actual{phone_day}
			);
	}
	elsif($transtype eq 'recurring') {
		%values = (
		 	szSerialNumber => $user,
			szDeveloperSerialNumber => $opt->{vendor},
			rtName => $actual{b_name},
			rtEmail => $actual{b_email},
			rtAddress1 => $actual{b_address},
			rtCity => $actual{b_city},
			rtState => $actual{b_state},
			rtPostalCode => $actual{b_zip},
			rtCountry => $actual{b_country},
			rtPhone => $actual{phone_day},
			rtAccountnumber => $actual{mv_credit_card_number},
			rtExpMonth =>  $ccem,
			rtExpYear => $ccey,
			rtItemNumber => $opt->{item_code},
			rtItemDescription => $opt->{item_description},
			rtAmount => $amount,
			rtStartingDate => $opt->{start_date},
			rtFrequency => $SJ_RT_FREQ{$opt->{frequency}},
			rtTotalTransactions => $opt->{total_transactions},
			rtOrderNumber => $opt->{order_id},
			rtComment => $actual{gift_note},
		);
	}

#::logDebug("Values to be sent: " . ::uneval(%values));

	$opt->{submit_url} = $opt->{submit_url}
				   || 'https://www.skipjackic.com/scripts/evolvcc.dll?Authorize';

	my $thing = post_data($opt, \%values);

	## check for errors
	my $error;

#::logDebug("request returned: $thing->{result_page}");

	my %result;

	if($transtype eq 'sale') {
		my @lines = split /</, $thing->{result_page};
		@lines = grep /\!-+/, @lines;
		for (@lines) {
#::logDebug("found response line=$_");
			s/-->.*//s;
			if (/^!--(.*)/) {
				my ($name, $val) = split(/=/,$1);
#::logDebug("name=$name value=$val");
				$result{$name} = $val;
			}
		}
		if ($result{szAuthorizationResponseCode} ne "") {
			$result{MStatus} = $result{'pop.status'} = 'success';
			$result{'order-id'} = $opt->{order_id};
		}
		else {
			$result{MStatus} = 'failed';
			$result{MErrMsg} =  $SJ_ERRORS{$result{szReturnCode}}
		}
	}
	elsif ($transtype eq 'recurring') {
		$thing->{result_page} =~ s/\"//g;
		my ($ron,$rc,$rn) = split(/\,/, $thing->{result_page});
		$result{szAuthorizationResponseCode} = $ron || '';
		if($rc == 0) {
			$result{MStatus} = 'success';
			$result{'order-id'} = $ron;
		}
		else {
			$result{MStatus} = 'failed';
			$result{MErrMsg} =  $SJ_RC_ERRORS{$rc}
		}
	}
	else {
		return (
			MStatus => 'failure-hard',
			MErrMsg => ::errmsg('unknown transction type: %s',$transtype),
		);
	}

    # Interchange names are on the  left, Skipjack on the right
    my %result_map = ( qw/
            pop.ref-code          szSerialNumber
            pop.auth-code         szAuthorizationResponseCode
            pop.avs_code          szAVSResponseCode
            pop.avs_reason        szAVSResponseMessage
			pop.txn-id            szOrderNumber
			pop.price             szTransactionAmount
			pop.error-message     szAuthorizationResponseCode
			pop.cvv2_code         szCVV2ResponseCode
			pop.cvv2_reason       szCVV2ResponseMessage
            icp_ref_code          szSerialNumber
            icp_auth_code         szAuthorizationResponseCode
            icp_avs_code          szAVSResponseCode
            icp_avs_reason        szAVSResponseMessage
			icp_txn_id            szOrderNumber
			icp_price             szTransactionAmount
			icp_error_message     szAuthorizationResponseCode
			icp_cvv2_code         szCVV2ResponseCode
			icp_cvv2_reason       szCVV2ResponseMessage
    /
    );

    for (keys %result_map) {
        $result{$_} = $result{$result_map{$_}}
            if defined $result{$result_map{$_}};
    }

#::logDebug("Skipjack request result: " . ::uneval(\%result) );

	return %result;
}

package Vend::Payment::Skipjack;

1;
