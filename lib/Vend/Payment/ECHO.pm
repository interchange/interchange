# Vend::Payment::ECHO - Interchange ECHO support
#
# $Id: ECHO.pm,v 1.10 2009-03-16 19:34:00 jon Exp $
#
# Copyright (C) 2002-2005
# Interchange Development Group
# Electric Pulp. <info@electricpulp.com> 
# Kavod Technologies <info@kavod.com>
#
# VERSION HISTORY
# + v1.1 08/06/2002 Fixed a problem with handling the return status from the
#   OpenECHO module.
# + v1.2 08/17/2002 General clean up
# + v1.3 08/22/2002 Ported from globalsub to Vend::Payment
#
#	http://www.openecho.com/
#	http://www.echo-inc.com/
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

package Vend::Payment::ECHO;

=head1 NAME

Vend::Payment::ECHO - Interchange ECHO Support

=head1 AUTHOR

Michael Lehmkuhl <michael@electricpulp.com>.

Ported to Vend::Payment by Dan Browning <db@kavod.com>.  Code reused and 
inspired by Mike Heins <mike@perusion.com>.

=head1 SPECIAL THANKS

Jim Darden <support@openecho.com>, Dan Browning <db@kavod.com>

=head1 SYNOPSIS

    &charge=echo
 
        or
 
    [charge mode=echo param1=value1 param2=value2]

=head1 PREREQUISITES

If you have not done so already, you will need to sign up for an ECHO account.
You will be provided an ID and a PIN (also known as 'secret').  You may also
sign up for a test account at the following URL:

    http://www.echo-inc.com/echotestapp.php

This subroutine uses the OpenECHO module.  Make sure OpenECHO.pm is in your @INC
array.  It is available for download, see the following URLs:
  
    http://www.openecho.com/
    http://www.echo-inc.com/
  
The OpenECHO.pm module itself has some additional prerequisites:

    Net::SSLeay
 
	or
  
    LWP::UserAgent and Crypt::SSLeay

Only one of these need be present and working.  Net::SSLeay is preferred as some
have reported problems using LWP::UserAgent and Crypt::SSLeay.

    URL::Escape

This module is used to write some of the URLs used by the OpenECHO module.  It
is recommended that you read the documention for the OpenECHO module itself in
addition to this document.

=head1 DESCRIPTION

The Vend::Payment::ECHO module implements the echo() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::ECHO

This I<must> be in interchange.cfg or a file included from it.

NOTE: Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<echo>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable MV_PAYMENT_MODE  echo

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    Route echo id Your_ECHO_ID

or  (with only ECHO as a payment provider)
    
     Variable MV_PAYMENT_ID	Your_ECHO_ID

or

     Variable ECHO_PAYMENT_ID	Your_ECHO_ID

or
 
     [charge mode=echo id=Your_ECHO_ID]

The active settings are:

=over 4

=item id

Your account ID, supplied by ECHO when you sign up.
Global parameter is MV_PAYMENT_ID or ECHO_PAYMENT_ID.

=item secret

Your account password, selected by you or provided by ECHO when you sign up.
Global parameter is MV_PAYMENT_SECRET or ECHO_PAYMENT_SECRET.

=item others...

If planning to do AUTH_ONLY or other with special admin page
Variable MV_PAYMENT_REMAP order_id=mv_order_id auth_code=mv_auth_code

    Variable ECHO_PAYMENT_ORDER_TYPE         S
	    # S for "self-service" orders
	    # F for hosted or ISP orders
    Variable ECHO_PAYMENT_ISP_ECHO_ID        123<4567890
    Variable ECHO_PAYMENT_ISP_PIN            12345608
    Variable ECHO_PAYMENT_MERCHANT_EMAIL     merchant@merchant.com
    Variable ECHO_PAYMENT_DEBUG              F
	    # C causes ECHO to return a statement of conformity
	    # T or TRUE causes ECHO to return additional debug information
	    # Any other value turns off ECHO debugging

=back 

=head2 Example Configuration

This is an example configuration that one would add to catalog.cfg: 

    Variable MV_PAYMENT_ID	Your_ECHO_ID
    Variable MV_PAYMENT_SECRET	Your_ECHO_secret
    Variable MV_PAYMENT_MODE	echo

=head2 Troubleshooting

Try a sale with the card number C<4111 1111 1111 1111> and a valid expiration 
date. The sale should be denied, and the reason should be in 
[data session payment_error].

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::ECHO

=item *

Make sure the ECHO C<OpenECHO.pm> module is available either in your
path or in /path_to_interchange/lib.

=item *

Check the error logs, both catalog and global.

=item *

Make sure you set your account ID and secret properly.  

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

If all else fails, Interchange consultants are available to help
with integration for a fee.

=back

=head1 SECURITY CONSIDERATIONS

Because this library calls an executable, you should ensure that no
untrusted users have write permission on any of the system directories
or Interchange software directories.

=head1 NOTES

There is actually nothing *in* Vend::Payment::ECHO. It changes packages
to Vend::Payment and places things there.

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

use OpenECHO;

sub echo {

	my ($user, $amount) = @_;

	my $opt;
	my $secret;
	
	if(ref $user) {
		$opt = $user;
		$user = $opt->{id} || undef;
		$secret = $opt->{secret} || undef;
	}
	else {
		$opt = {};
	}

#::logDebug("echo called, args=" . ::uneval(\@_));
	
	my (%actual) = map_actual();
	
	my @errMsgs = ();
	# Required for validation
	if (! $user) {
		$user      = $opt->{id} || 
		             charge_param('id') ||  
		             $::Variable->{ECHO_PAYMENT_ID} ||
		             $::Variable->{MV_PAYMENT_ID} ||
	                $::Variable->{CYBER_ID}
	                or push @errMsgs, "No payment ID found.";
	}
	
	# Required for validation
	if (! $secret) {
		$secret    = $opt->{secret} ||
		             charge_param('secret') ||
						 $::Variable->{ECHO_PAYMENT_SECRET} ||
						 $::Variable->{MV_PAYMENT_SECRET} ||
		             $::Variable->{CYBER_SECRET}
		             or push @errMsgs, "No payment secret found.";
	}

	if (scalar @errMsgs) {
		for (@errMsgs) {
			::logError($_);
		}
		return 0;
	}
	@errMsgs = ();

   my $server     = $opt->{server} ||
                     charge_param('server') ||
							$::Variable->{ECHO_PAYMENT_SERVER} ||
							$::Variable->{MV_PAYMENT_SERVER} ||
                     $::Variable->{CYBER_SERVER} ||
                     'https://wwws.echo-inc.com/scripts/INR200.EXE';

	my $precision  =  $opt->{precision} ||
                     charge_param('precision') ||
							$::Variable->{ECHO_PAYMENT_PRECISION} ||
							$::Variable->{MV_PAYMENT_PRECISION} ||
                     $::Variable->{CYBER_PRECISION} ||
                     2;

	##### ECHO SPECIFIC VARIABLES #####

	my $order_type = $::Variable->{ECHO_PAYMENT_ORDER_TYPE} || 'S';
	my $isp_echo_id = $::Variable->{ECHO_PAYMENT_ISP_ECHO_ID};
	my $isp_pin = $::Variable->{ECHO_PAYMENT_ISP_PIN};
	my $merchant_email = $::Variable->{ECHO_PAYMENT_MERCHANT_EMAIL};

	# Set to 'C' for Certify mode to check compliance with the ECHO spec on a
	# transaction-by-transaction basis.  'T' or 'TRUE' for full ECHO debugging.
	my $debug = $::Variable->{ECHO_PAYMENT_DEBUG};

	##########################

	$actual{mv_credit_card_exp_month} =~ s/\D//g;
	$actual{mv_credit_card_exp_month} =~ s/^0+//;
	$actual{mv_credit_card_exp_year} =~ s/\D//g;
	$actual{mv_credit_card_exp_year} =~ s/\d\d(\d\d)/$1/;

	$actual{mv_credit_card_number} =~ s/\D//g;

	my $exp = sprintf '%02d%02d',
                        $actual{mv_credit_card_exp_month},
                        $actual{mv_credit_card_exp_year};

	# Using mv_payment_mode for compatibility with older versions, probably not
	# necessary.
	$actual{cyber_mode} = $actual{mv_payment_mode} || 'ES'
        unless $actual{cyber_mode};

	# Credit Card Transactions 
	# *	AD (Address Verification) 
	# *	AS (Authorization) 
	# *	AV (Authorization with Address Verification) 
	# *	CR (Credit) 
	# *	DS (Deposit) 
	# *	ES (Authorization and Deposit) 
	# *	EV (Authorization and Deposit with Address Verification) 
	# *	CK (System check) 
	# Credit Card Transactions Enhanced by CyberSource 
	# *	CI (AV Transaction with CyberSource Internet Fraud Screen) 
	# *	CE (AV Transaction with CyberSource Export Compliance) 
	# *	CB (AV Transaction with CyberSource Internet Fraud Screen and Export Compliance) 
	# Electronic Check Transactions 
	# *	DV (Electronic Check Verification) 
	# *	DD (Electronic Check Debit) 
	# *	DC (Electronic Check Credit)
	my %type_map = (
		mauth_capture 			=>	'ES',
		EV						=>  'EV',
		mauthonly				=>	'AS',
		CAPTURE_ONLY			=>  'DS',
		CREDIT					=>	'CR',
		AUTH_ONLY				=>	'AS',
		PRIOR_AUTH_CAPTURE		=>	'DS',
	);
	
	if (defined $type_map{$actual{cyber_mode}}) {
        $actual{cyber_mode} = $type_map{$actual{cyber_mode}};
    }
    else {
        $actual{cyber_mode} = 'ES';
    }

    if(! $amount) {
        $amount = Vend::Interpolate::total_cost();
        $amount = Vend::Util::round_to_frac_digits($amount,$precision);
    }

    my($orderID);
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time());

    ### Make an order ID based on date, time, and Interchange session
    # $mon is the month index where Jan=0 and Dec=11, so we use
    # $mon+1 to get the more familiar Jan=1 and Dec=12
    #$orderID = sprintf("%04d%02d%02d%02d%02d%05d%s",
    #        $year + 1900,$mon + 1,$mday,$hour,$min,$$,$Vend::SessionName);
	$orderID = Vend::Payment::gen_order_id();

	### Set up the OpenECHO instance
	use OpenECHO;
	my $openecho = new OpenECHO or push @errMsgs, "Couldn't make instance of OpenECHO.";
	if (scalar @errMsgs) {
		for (@errMsgs) {
			::logError($_);
		}
		return 0;
	}
	@errMsgs = ();

	### Connection info
	$openecho->set_EchoServer("https://wwws.echo-inc.com/scripts/INR200.EXE");
	$openecho->set_transaction_type($actual{cyber_mode});
	$openecho->set_order_type($order_type);

	### Merchant/ISP info
	$openecho->set_merchant_echo_id($user);
	$openecho->set_merchant_pin($secret);
	$openecho->set_isp_echo_id($isp_echo_id);
	$openecho->set_isp_pin($isp_pin);
	$openecho->set_merchant_email($merchant_email);

	### Billing info
	my $billing_first_name = $actual{b_fname} || $actual{fname};
	my $billing_last_name = $actual{b_lname} || $actual{lname};
	my $billing_address1 = $actual{b_address1} || $actual{address1};
	my $billing_address2 = $actual{b_address2} || $actual{address2};
	my $billing_city = $actual{b_city} || $actual{city};
	my $billing_state = $actual{b_state} || $actual{state};
	my $billing_zip = $actual{b_zip} || $actual{zip};
	my $billing_country = $actual{b_country} || $actual{country};
	my $billing_phone = $actual{phone_day} || $actual{phone_night};
	$openecho->set_billing_ip_address($Vend::Session->{ohost});		# aka [data session ohost] aka REMOTE_HOST
	#$openecho->set_billing_prefix($actual{prefix});
	$openecho->set_billing_first_name($billing_first_name);
	$openecho->set_billing_last_name($billing_last_name);
	#$openecho->set_billing_company_name($actual{company_name});
	$openecho->set_billing_address1($billing_address1);
	$openecho->set_billing_address2($billing_address2);
	$openecho->set_billing_city($billing_city);
	$openecho->set_billing_state($billing_state);
	$openecho->set_billing_zip($billing_zip);
	$openecho->set_billing_country($billing_country);
	$openecho->set_billing_phone($billing_phone);
	#$openecho->set_billing_fax($actual{fax});
	$openecho->set_billing_email($actual{email});

	### Electronic check payment info if supplied...
	#$openecho->set_ec_bank_name($ec_bank_name);
	#$openecho->set_ec_first_name($billing_first_name);
	#$openecho->set_ec_last_name($billing_last_name);
	#$openecho->set_ec_address1($billing_address1);
	#$openecho->set_ec_address2($billing_address2);
	#$openecho->set_ec_city($billing_city);
	#$openecho->set_ec_state($billing_state);
	#$openecho->set_ec_zip($billing_zip);
	#$openecho->set_ec_rt($ec_rt);
	#$openecho->set_ec_account($ec_account);
	#$openecho->set_ec_serial_number($ec_serial_number);
	#$openecho->set_ec_payee($ec_payee);
	#$openecho->set_ec_id_state($ec_id_state);
	#$openecho->set_ec_id_number($ec_id_number);
	#$openecho->set_ec_id_type($ec_id_type);

	### Debug on/off
	$openecho->set_debug($debug);
	
	### Payment details
	$openecho->set_cc_number($actual{mv_credit_card_number});
	$openecho->set_grand_total($amount);
	$openecho->set_ccexp_month($actual{mv_credit_card_exp_month});
	$openecho->set_ccexp_year($actual{mv_credit_card_exp_year});
	$openecho->set_counter($openecho->getRandomCounter());
	$openecho->set_merchant_trace_nbr($orderID);
	
	### Send payment request
	#print($openecho->get_version() . "<BR>");
#::logDebug("openecho submitting <urldata>%s</urldata>", $openecho->getURLData());
	$openecho->Submit();

#::logDebug("The ECHO response is <echo_response>%s</echo_response>", $openecho->{'EchoResponse'});

#::logDebug("The ECHO type 2 response is <echotype2>%s</echotype2>", $openecho->{'echotype2'});

#::logDebug("The avs_result field is <avs_result>%s</avs_result>", $openecho->{avs_result});

	my %result;
	if ($openecho->{EchoSuccess} != 0) {
		$result{'MStatus'} = 'success';
		$result{'pop.status'} = 'success';
		$result{'MErrMsg'} = $openecho->{'echotype2'};
		$result{'pop.error-message'} = $openecho->{'echotype2'};
		$result{'order-id'} = $openecho->{order_number} || 1;
		$result{'pop.order-id'} = $openecho->{order_number} || 1;
		$result{'auth_code'} = $openecho->{auth_code};
		$result{'pop.auth_code'} = $openecho->{auth_code};
		$result{'avs_code'} = $openecho->{avs_result};
		$result{'pop.avs_code'} = $openecho->{avs_result};
	}
	else {
		$result{MStatus} = 'failure';
		$Vend::Session->{MStatus} = 'failure';
		
		# NOTE: A lot more AVS codes could be checked for here.
		if ($result{avs_code} eq 'N') {
			$result{MErrMsg} = "You must enter the correct billing address of your credit card. The bank returned the following error: " . $openecho->{'avs_result'};
		}
		else {
			$result{MErrMsg} = $openecho->{'echotype2'};
		}
		$Vend::Session->{payment_error} = $result{MErrMsg};
#::logDebug("openecho oops: ".$Vend::Session->{payment_error});
	}

    return (%result);
}

package Vend::Payment::ECHO;

return 1;
