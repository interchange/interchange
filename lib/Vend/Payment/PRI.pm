# Vend::Payment::PRI - Interchange PRI support
#
# $Id: PRI.pm,v 1.6 2007-08-09 13:40:55 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1999-2002 Red Hat, Inc.
#
# Written by Marty Tennison, Based on code by Cameron Prince and Mark Johnson,
# which in turn was based on code by Mike Heins.

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

package Vend::Payment::PRI;

=head1 NAME

Vend::Payment::PRI - Interchange PRI Support

=head1 SYNOPSIS

    &charge=PRI

        or

    [charge mode=PRI param1=value1 param2=value2]

=head1 PREREQUISITES

  Net::SSLeay
 
    or
  
  LWP::UserAgent and Crypt::SSLeay

Only one of these need be present and working.

=head1 DESCRIPTION

The Vend::Payment::PRI module implements the PRI() routine for using
Payment Resources International payment services with Interchange. It is
compatible on a call level with the other Interchange payment modules -- in
theory (and even usually in practice) you could switch from CyberCash to PRI
with a few configuration file changes.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::PRI

This I<must> be in interchange.cfg or a file included from it.

NOTE: Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<PRI>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  PRI

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge mode=PRI id=YourPRIID]

or

    Route PRI id YourPRIID

or with only PRI as a payment provider

    Variable MV_PAYMENT_ID      YourPRIID

A fully valid catalog.cfg entry to work with the standard demo would be:

    Variable MV_PAYMENT_MODE    "__MV_PAYMENT_MODE__"
		Route  PRI      id          "__PRI_ID__"
		Route  PRI      regkey      "__PRI_REGKEY__"
		Route  PRI      test_id     "__PRI_TEST_ID__"
		Route  PRI      test_regkey "__PRI_TEST_REGKEY__"
		Route  PRI      test_mode   "__PRI_TEST_MODE__"
		Route  PRI      refid_mode  "__PRI_REFID_MODE__"
		
A fully valid variable.txt entry to work with the PRI module would be:

		MV_PAYMENT_MODE	PRI	Payment
		PRI_ID	your_pri_id	Payment
		PRI_REGKEY	your_pri_regkey	Payment
		PRI_TEST_ID	your_pri_test_id	Payment
		PRI_TEST_REGKEY	your_pri_test_regkey	Payment
		PRI_TEST_MODE	1	Payment
		PRI_REFID_MODE	1	Payment


The active settings are:

=over 4

=item id

PRI will supply you with both a test id and production id.  Enter both of these numbers into the the variables above.  You do not need your production id to test. 

=item regkey

PRI will supply you with both a test regkey and production regkey.  Enter both of these numbers into the the variables above.  You do not need your production regkey to test. 

=item refid

The PRI interface allows (requires) a field called REFID.  This field is stored along with the transaction on the PRI server and allows your to do quick searches for transactions if this number has meaning.  There are three possible values for the PRI_REFID_MODE variable.  1,2 or any other character or null.  

	1.  A "1" in the pri_refid_mode instructs interchange to read the current
	order number in $Variable->{MV_ORDER_COUNTER_FILE} or "etc/order.number",
	increment it by one and use that. Do not use this mode if you have a busy catalog.  PRI might reject orders as duplicates if two people try to checkout at the same time.
	
	2. A "2" in the pri_refid_mode instructs interchange to use the users
	session_id as the value.  This is the recommended mode.
	
	3. Anything other than a 1 or 2 instructs interchange to generate a unique
	number from the unix date command and use that.  The number format is Day of
	year, Hours, Minutes, Seconds.  Example for Jan 1, at 1:00:30 is 001130030.

=item transaction

At this time the PRI payment module only processes transactions of type SALE.

=item test

Testing with PRI is straight forward.  At this time (2004-05-15), PRI uses the same server for both development and production.  The only difference is the account used.  Some accounts are flagged as TEST accounts and others are live.  When you first sign up with PRI they will supply you a test account and test Registration Key to use.  Enter those numbers in the PRI_ID, PRI_REGKEY (production) and PRI_TEST_ID, PRI_TEST_REGKEY (test) variables.  Set the PRI_TEST_MODE to a value of 1,2 or 3 then do your testing.  Once everything is working correctly, simply set PRI_TEST_MODE to 0 and restart interchange.  Your now live.

Testing has 3 modes. (1,2,3) (live mode is 0) You set the mode with the PRI_TEST_MODE variable in variable.txt or directly in your catalog.cfg file.  The modes are as follows.

1) Use PRI_TEST_ID and PRI_TEST_REGKEY values.  Send information to PRI and receive result from PRI.  To generate errors in this mode, simply enter invalid data and PRI should reject it with an error.  

2) Generate a declined order internally.  Does not send data to PRI.  This mode is convenient if you want to do some testing and do not want to send any data to PRI.  It's also a good way to track down errors.

3) Generate a successful sale internally.  Does not send data to PRI. This mode is convenient if you want to see if everything works before sending test data to PRI.

A good way to test this module is to set PRI_TEST_MODE to 3, then 2, then 1, then 0 and make sure your catalog handles all situations correctly.


=item generate_error

To generate errors in test mode (while using your test ID and regkey) simply enter transactions with bad data and see what happens.  PRI will supply you with a list of test credit card numbers and amounts that they are good for. 

=over 4

=item submit_url

PRI uses different URLs depending on what type of transaction you are requesting, Sale, Recurring, Void etc..  The default URL for single sale transactions is

	 https://webservices.primerchants.com/billing/TransactionCentral/processCC.asp?

At this time, this is the only URL supported by this PRI module
	 
=back

=head2 Troubleshooting

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::PRI

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

There is actually nothing *in* Vend::Payment::PRI. It changes packages
to Vend::Payment and places things there.

=head1 AUTHORS

Originally developed by New York Connect Net (http://nyct.net)
Michael Bacarella <mbac@nyct.net>

Modified for GetCareer.com by Slipstream.com by Troy Davis <troy@slipstream.com>

LWP/Crypt::SSLeay interface code by Matthew Schick,
<mschick@brightredproductions.com>.

Interchange implementation by Mike Heins.

PRI modification by Marty Tennison

=head1 VERSION HISTORY

05-24-2004 - Version 1.0

09-06-2004 -.Version 1.1
  Added testing mode support.
	Changed default refid to mode 2.
	Fixed bug where PRI.pm would not recognize a successful transaction with a mix of digits and letters.  Now checks for "Declined", <space> or <null> to determine declined transaction, all others succeed.
	Cleaned up some code.

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
		unless $Vend::Quiet;

}

package Vend::Payment;

use vars qw/%PRI_AVS_CODES/;
use vars qw/$Have_LWP $Have_Net_SSLeay/;

%PRI_AVS_CODES = (
	'X' => 'Exact match, 9 digit zip',
	'Y' => 'Exact match, 5 digit zip',
	'A' => 'Address match only',
	'W' => '9 digit match only',
	'Z' => '5 digit match only',
	'N' => 'No address or zip match',
	'U' => 'Address unavailable',
	'R' => 'Retry - Issuer system unavailable',
	'E' => 'ERROR INELIGIBLE - Not a mail/phone number',
	'S' => 'SERVICE UNAVAILABLE - Service not supported',
	'G' => 'AVS NOT AVAILABLE - Non U.S. Issuer',
	'B' => 'ADDRESS MATCH - Street address match',
	'C' => 'Street and post not verified for international',
	'D' => 'Good street and post net match',
	'F' => 'Good street and post net match - UK',
	'I' => 'Address not verified',
	'M' => 'Street address and post net match',
	'P' => 'Postal net matched, Street address not verified'
);

sub PRI {
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

	my $ccem = $actual{mv_credit_card_exp_month};
	$ccem =~ s/\D//g;
	$ccem =~ s/^0+//;
	$ccem = sprintf('%02d', $ccem);

	my $ccey = $actual{mv_credit_card_exp_year};
	$ccey =~ s/[\t\r\n]//g;
	$ccey =~ s/^\s*//g;
	$ccey =~ s/\s*$//g;
	chomp $ccey;

	$actual{mv_credit_card_number} =~ s/\D//g;

	my $precision = $opt->{precision} || charge_param('precision') || 2;

	$amount = $opt->{total_cost} || undef;

	$opt->{transaction} ||= 'sale';
	my $transtype = $opt->{transaction};

	my %type_map = (
	);
	
	if ( defined $type_map{$transtype} ) {
		$transtype = $type_map{$transtype};
	}

	if ( ! $amount ) {
		$amount = Vend::Interpolate::total_cost();
		$amount = Vend::Util::round_to_frac_digits($amount,$precision);
	}

	# figure out what refid should be
	if ( $opt->{refid_mode} == 1 ) {
		my $cfn = $Variable->{MV_ORDER_COUNTER_FILE} || 'etc/order.number';
		$new_order_number = $Tag->file($cfn);
		$new_order_number =~ s/.*\n([A-Za-z0-9]+).*$/$1/s;
		++$new_order_number;
		$refid = $new_order_number;
	}
	elsif ( $opt->{refid_mode} == 2 ) {
		$refid = $Vend::SessionID;
	}
	else {
		$refid = `date +%j%k%M%S`;
		chomp $refid;
	}

	my %result;
	my $result_page;

	# See if we are in test mode, and if so, what mode
	if ( $opt->{test_mode} >= 1 ) {
		$merchantid = $opt->{test_id};
		$regkey = $opt->{test_regkey};
		if ( $opt->{test_mode} == 2 ) {
			$result_page = "TransID=&REFNO=12345&Auth=Declined&AVSCode=&CVV2ResponseMsg=&Notes=M4 / Please Try Again (Default message)&User1=&User2=&User3=&User4=";
		}
		elsif ( $opt->{test_mode} == 3 ) {
			$result_page = " TransID=12T4567&REFNO=12T45&Auth=12T45&AVSCode=Y&CVV2ResponseMsg=M&Notes=Notes here&User1=&User2=&User3=&User4=";
		}
	} 
	else {
		$merchantid = $opt->{id};
		$regkey = $opt->{regkey};
	}
	
	my %values;
	if ( $transtype eq 'sale' ) {
		%values = (
			MerchantID => $merchantid,
			RegKey => $regkey,
			Amount => $amount,
			REFID => $refid,
			AccountNo => $actual{mv_credit_card_number},
			CCMonth => $ccem,
			CCYear => $ccey,
			NameonAccount => $actual{b_name},
			AVSADDR => $actual{b_address},
			AVSZIP => $actual{b_zip},
			CCRURL => "",
			CVV2 => $actual{cvv2},
			);
	}

#::logDebug("Values to be sent: " . ::uneval(%values));

	$opt->{submit_url} ||= 	 'https://webservices.primerchants.com/billing/TransactionCentral/processCC.asp?';

#::logDebug("sending query: " . ::uneval(\%values));

	# Interchange names are on the  left, PRI on the right
	my %result_map = ( qw/
		pop.ref-code          TransID
		pop.auth-code         Auth
		pop.avs_code          AVSCode
		pop.txn-id            RefNo
		pop.error-message     Notes
		pop.cvv2_code         CVV2ResponseMessage
	/
	);

	if ( $opt->{test_mode} <= 1 ) {
		my $thing      = post_data($opt, \%values);
		$result_page   = $thing->{result_page};
	}

	## check for errors
	my $error;

#::logDebug("restul_page before cleanup: $result_page");

	# strip html from result_page and clean it up
	$result_page =~ s/\<.*?\>//g;
	$result_page =~ s/[\t\r\n]//g;
	$result_page =~ s/^\s*//g;
	$result_page =~ s/\s*$//g;
	
#::logDebug("restul_page after cleanup: $result_page");

	%$result = split /[&=]/, $result_page;
	
	# if the Auth code contains Declined, or if it is
	# null or a space, we failed.
	if ( ! $result->{Auth} || $result->{Auth} =~ /Declined/ || $result->{Auth} eq " "  ) {
#::logDebug("Transaction declined: $result->{Auth}: $result->{Notes}");
		$result->{MStatus} = 'failed';
		if ( $result->{Notes} ) {
			$result->{MErrMsg} = "$result->{Auth} $result->{Notes}";
		}
		else {
			$result->{MErrMsg} = "Unknown error";
		}
	}
	else {
#::logDebug("Transaction approved: $result->{Auth}: $result->{Notes}");
		$result->{MStatus} = $result->{'pop.status'} = 'success';
		$result{MStatus} = $result->{'pop.status'} = 'success';
		$result->{'pop.order-id'} = $result->{TransID};
		$result->{'order-id'} = $result->{TransID};
		$::Values->{avs} = $result->{AVSCode};
		$::Values->{cvv2} = $result->{CVV2ResponseMsg};
		$::Values->{auth} = $result->{Auth};
		$result->{AUTHCODE} = $result->{Auth};
		$result->{ICSTATUS} = 'success';
	}

    for (keys %result_map) {
        $result->{$_} = $result->{$result_map{$_}}
            if defined $result->{$result_map{$_}};
    }
		
#::logDebug(qq{PRI query result: } . ::uneval($result));

	return %$result;

}

package Vend::Payment::PRI;

1;
