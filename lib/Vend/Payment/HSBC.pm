# Vend::Payment::HSBC - Interchange HSBC Payment module
#
# Copyright (C) 2013 Zolotek Resources Ltd
# All Rights Reserved.
#
# Author: Lyn St George <lyn@zolotek.net>
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
#
package Vend::Payment::HSBC;

=head1 NAME

Vend::Payment::HSBC - Interchange HSBC Payments Module

=head1 PREREQUISITES

    XML::Simple
    URI
    libwww-perl
    Net::SSLeay
	HTTP::Request
	
Test for current installations, eg: perl -MXML::Simple -e 'print "It works\n"'
To install perl modules do: "emerge dev-perl/XML-Simple" or so on Gentoo, or on other systems do
"perl -MCPAN -e  'install XML::Simple'"

=head1 DESCRIPTION

The Vend::Payment::HSBC module implements the HSBC payment routine for use with Interchange.

#=========================

=head1 SYNOPSIS

Quick start:

Place this module in <ic_root>/lib/Vend/Payment, and call it in <ic_root>/interchange.cfg with
Require module Vend::Payment::HSBC. Ensure that your perl installation contains the modules
listed above and their pre-requisites.

Add a new payment route into catalog.cfg as follows:
Route hsbc gwhost https://www.secure-epayments.apixml.hsbc.com 
Route hsbc tdshost https://www.ccpa.hsbc.com/ccpa
Route hsbc returnurl http://__SERVER_NAME__/ord/hsbctdsreturn
Route hsbc username XXnnnnnn
Route hsbc currency GBP (default if not otherwise specified)
Route hsbc lcusername "XXX XXX" (currency codes, if they give you some usernames in lowercase and others in uppercase)
Route hsbc clientidGBP	nnnnn (5 digit number for that currency)
Route hsbc clientidEUR	nnnnn
Route hsbc clientidXXX	nnnnn
Route hsbc clientalias XXnnnnnnnn (ie country code plus your 8-digit merchant a/c id)
Route hsbc password xxx
Route hsbc txmode P (see below for others)
Route hsbc txtype Auth (PreAuth, Auth, PostAuth, Void, Credit, ForceInsertPreAuth,ForceInsertAuth, ReAuth, RePreAuth, ReviewPendingUpdate)
Route hsbc payment_type PaymentNoFraud (or Payment to use their fraud routines)
Route hsbc finalcheckoutpage ord/final (defaults to ord/checkout)
Route hsbc payment_type PaymentNoFraud (bypasses fraud checks, default is 'Payment' to run checks)

Route hsbc mail_txn_approved 1 (email you messages, a la Paypal, of payment made)
Route hsbc mail_txn_declined 1 (email you messages of payments declined, for monitoring fraud attempts) 
Route hsbc mail_txn_to (merchant's email address, defaults to EMAIL_SERVICE or ORDERS_TO)
Route hsbc hsbcrequest gwpost (to bypass 3DSecure, defaults to tdspost)

Add the following block of fraud screening rules, including comments as reminders. 
# Default fraud rules: mark '1' to accept the order conditional upon further processing, '2' to display the message to the 
# customer. Mark '0' to reject the order, or to not display a message. Eg '0 2' will reject with the message.
# '1 0' will accept and complete the order but not display a message, '1 2' will accept and display a message.
# All of these cases will be 'approved' by default but marked as 'review before capturing funds' by the bank.
Route hsbc fraud_4 '1 2' # The customer's billing address is in the UK but they 
						  # are using an overseas issued card.
Route hsbc fraud_5 '1 2'  # The customer is using a card issued in a different 
						  # country to the billing address.
Route hsbc fraud_6 '0 2'  # Failed AVS check.  Both the first line of the address 
						  # and post code do not match the address held by the card issuer.
Route hsbc fraud_16 '0 2' # Failed AVS check.  Only the first line of the address matches 
						  # the address held by the card issuer.
Route hsbc fraud_17 '1 2' # Failed AVS check.  Only the post code matches the address held 				
						  # by the card issuer.
Route hsbc fraud_7 '1 0'  # The card issuer has not responded to the AVS request. 
Route hsbc fraud_8 '0 2'  # CVM does not match the card issuer's value.
Route hsbc fraud_9 '0 2'  # <BillToName> appears to be an invalid name. 
Route hsbc fraud_10 '0 2' # <BillToStreet1> appears to be an invalid address.
Route hsbc fraud_11 '0 2' # <BillToCity> appears to be an invalid address.
Route hsbc fraud_12 '0 0' # <BillToPostalCode> appears to be an invalid address. 
Route hsbc fraud_13 '1 0' # The AVS check cannot be performed on a British Forces Postal Office address.  
Route hsbc fraud_14 '0 0' # HSBC Merchant Services has recently identified a number of fraudulent 
						  # orders originating from this location.
Route hsbc fraud_15 '0 0' # HSBC Merchant Services has recently identified a number of fraudulent 
						  # orders originating from this location.
Route hsbc fraud_20 '0 0' # HSBC Merchant Services has recently observed a high incidence of 
						  # fraudulent transactions using the name '<BillToName>'.
Route hsbc fraud_22 '0 0' # HSBC Merchant Services has recently identified a number of fraudulent 
						  # orders using this range of card numbers with a UK billing address. 
Route hsbc fraud_23 '0 0' # HSBC Merchant Services has recently identified a number of fraudulent 
						  # orders using this range of card numbers with Irish billing addresses.

If these rules are triggered, [scratch pspfraudmsg] will hold the message to display
to your customer, and should be included into the receipt, mail_receipt and report. In all
cases where a rule is triggered and payment needs manual review and acceptance an email will
be sent to the merchant with details.

TxMode: P = production, 
		Y = test 'yes' response 
		N = test, 'no' response
		R = test, random 'yes|no' response;
		FY = test, FraudShield 'yes' response
		FN = test, FraudShield 'no' response

Alter etc/log_transaction to wrap the following code around the "[charge route...]" call 
found in ln 172 (or nearby):
	[if scratchd mstatus eq success]
	[tmp name="charge_succeed"][scratch order_id][/tmp]
	[else]
	[tmp name="charge_succeed"][charge route="[var MV_PAYMENT_MODE]" amount="[scratch tmp_remaining]" order_id="[value mv_transaction_id]"][/tmp]
	[/else]
	[/if]
and change [var MV_PAYMENT_MODE] above to [value mv_payment_route] if you want to use Paypal or similar in conjunction with this

Also add this line just after '&final = yes' near the end of the credit_card section of etc/profiles.order:
	&set=mv_payment_route hsbc if you change [var MV_PAYMENT_MODE] as above


If run from some sort of terminal this will also make refunds or send funds to a specified
credit card.



=head1 Changelog
v 1.0.1, February 2013, change of ownership from eSecurePayments to GlobalIris and
  consequent change of URLs for gateway.
v 1.0.0, October 2011.
  first public release

=head1 AUTHORS

Lyn St George <lyn@zolotek.net>

=cut

BEGIN {
	eval {
		package Vend::Payment;
		require Net::SSLeay;
		require XML::Simple;
		require XML::Parser;
		require LWP;
		require MIME::Base64;
		require HTTP::Request::Common;
		import HTTP::Request::Common qw(POST);
		use HTTP::Request  ();
		use MIME::Base64;
		import Net::SSLeay qw(post_https make_form make_headers);
	};

		$Vend::Payment::Have_Net_SSLeay = 1 unless $@;

	if ($@) {
		$msg = __PACKAGE__ . ' requires XML::Simple, HTTP::Request, Net::SSLeay and LWP ' . $@;
		::logGlobal ($msg);
		die $msg;
	}

	::logGlobal("%s v1.0.1 20130222 payment module loaded",__PACKAGE__)
		unless $Vend::Quiet or ! $Global::VendRoot;
}

package Vend::Payment;

use strict;

  my $gwhost;

sub hsbc {
    my ($method, $response, $in, $opt, $actual, %result, $db, $dbh, $sth, $transactionid, $id, $md, $x);
	my ($passoutdata,$telephone, $md, $cardref, $mailreview, $mailtxn, $display, $pass);
	my (%actual) = map_actual();
		$actual  = \%actual;
       $gwhost       = charge_param('gwhost') || 'https://apixml.globaliris.com';
	my $tdshost      = charge_param('tdshost') || 'https://mpi.globaliris.com/ccpa'; # 'https://www.ccpa.hsbc.com/ccpa'; # only live ..
	my $bypass3ds    = $::Values->{'bypass3ds'} || charge_param('bypass3ds') || '';
	my $hsbcrequest  = $::Values->{'hsbcrequest'} || charge_param('hsbcrequest') || 'gwpost'; 
					   $::Values->{'hsbcrequest'} = '';
	my $tdsreturn    = charge_param('tdsreturn') || '';
	   $hsbcrequest  = 'gwpost' if length $tdsreturn;
	my $mailto       = charge_param('mail_txn_to') || $::Variable->{'EMAIL_SERVICE'} || $::Variable->{'ORDERS_TO'};
	my $currency     = $::Values->{'iso_currency_code'} || $::Scratch->{'iso_currency_code'} || charge_param('currency') || 'GBP';
					   $::Values->{'iso_currency_code'} = '';
	my $clientID     = 'clientid' . $currency;
	my $clientid     = charge_param($clientID) or die "No client ID\n";
	my $clientalias  = charge_param('clientalias') or warn "No client Alias\n";
 	   $clientalias  .= $currency;
	my $ccpaclientid = $clientalias . "01";
	my $username     = charge_param('username') or die "No username id\n";
	   $username     = lc($username) if charge_param('lcusername') =~ /$currency/;
	my $password     = charge_param('password') or die "No password\n";
	my $txtype       = $::Values->{'txtype'} || charge_param('txtype') || 'Auth';
					   $::Values->{'txtype'} = '';
	my $paymenttype  = $::Values->{'payment_type'} || charge_param('payment_type') || 'Payment'; # PaymentNoFraud bypasses HSBC's fraud tests
					   $::Values->{'payment_type'} = '';
	my $txmode       = $::Values->{'txmode'} || charge_param('txmode') || 'P'; # P = production, others listed above
					   $::Values->{'txmode'} = '';
	my $authcode     = $::Values->{'authcode'} || ''; # Obtained by voice authorisation for ForceInsertPreauth and the like
	my $hsbctdspage  = charge_param('hsbctdspage') || 'ord/hsbctds'; 
	my $returnurl    = charge_param('returnurl') || "$::Variable->{SECURE_SERVER}$::Variable->{CGI_URL}/ord/hsbctdsreturn";
	my $finalcheckout = charge_param('finalcheckoutpage') || 'ord/checkout';
	my $currencyshort = $currency;
	   $currencyshort =~ /(\w\w)/i;

#::logDebug("HSBC".__LINE__.": req=$hsbcrequest; type=$txtype; mode=$txmode; clientID=$clientid; clientalias=$clientalias, currency=$currency, username=$username");	

	my $amount =  charge_param('amount') || Vend::Interpolate::total_cost() || $::Values->{'amount'}; 
	   $amount =~ s/^\D*//g;
	   $amount =~ s/\s*//g;
	my $purchaseamount = $amount;
	   $amount =~ s/,//g;
	   $amount =  sprintf '%.2f', $amount;
	   $amount =~ s/\.//g; # £10.00 becomes 1000 for HSBC; 'purchaseamount' is for display to customer at PAS
#::logDebug("HSBC".__LINE__.":cp-amnt: ".charge_param('amount')."; v-amnt: $::Values->{'amount'}; ic-total_cost=" . Vend::Interpolate::total_cost()); 	   
	my $usebill  = '';
	   $usebill  = '1' if ($::Values->{'mv_same_billing'} == '0' || length $::Values->{'b_lname'});
	my $name     = $usebill ? "$::Values->{'b_fname'} $::Values->{'b_lname'}" || '' : "$::Values->{'fname'} $::Values->{'lname'}" || '';
	my $address1 = $usebill ? $::Values->{'b_address1'} : $::Values->{'address1'};
	my $address2 = $usebill ? $::Values->{'b_address2'} : $::Values->{'address2'};
	my $address3 = $usebill ? $::Values->{'b_address3'} : $::Values->{'address3'};
	my $phone    = $::Values->{'phone_day'} || $::Values->{'phone_night'};
	my $address  = "$address1, $address2, $address3";
	   $address  =~ s/,\s+$//g;
	   $address  =~ s/[^a-zA-Z0-9,.\- ]//gi;
	my $city     = $usebill ? $::Values->{'b_city'} : $::Values->{'city'};
	   $city     =~ s/[^a-zA-Z0-9,.\- ]//gi;
	my $state    = $usebill ? $::Values->{'b_state'} : $::Values->{'state'};
	   $state    =~ s/[^a-zA-Z0-9,.\- ]//gi;
	my $zip      = $usebill ? $::Values->{'b_zip'} : $::Values->{'zip'};
	   $zip      =~ s/[^a-zA-Z0-9,.\- ]//gi;
	my $country  = $usebill ? $::Values->{'b_country'} : $::Values->{'country'};
	   $country  = 'GB' if ($country eq 'UK');
	my $email    = $actual->{'email'};
	   $email    =~ s/[^a-zA-Z0-9.\@\-_]//gi;
	my $phone    = $actual->{'phone_day'} || $actual->{'phone_night'};
	   $phone    =~ s/[\(\)]/ /g;
	   $phone    =~ s/[^0-9-+ ]//g;
	my $ipaddress  = $CGI::remote_addr if $CGI::remote_addr;
	   $ipaddress  =~ /(\d*)\.(\d*)\.(\d*)\.(\d*)/;
	my $t1 = sprintf '%03d', $1;
	my $t2 = sprintf '%03d', $2;
	my $t3 = sprintf '%03d', $3;
	my $t4 = sprintf '%03d', $4;
	   $ipaddress = "$t1.$t2.$t3.$t4" if $CGI::remote_addr;

	my $pan = $actual->{'mv_credit_card_number'};
 	   $pan =~ s/\D//g;
	   $actual->{'mv_credit_card_exp_month'}    =~ s/\D//g;
	   $actual->{'mv_credit_card_exp_year'}     =~ s/\D//g;
	   $actual->{'mv_credit_card_exp_year'}     =~ s/\d\d(\d\d)/$1/;

	   if (length $pan) {
		  $cardref  = $pan;
		  $cardref =~ s/^(\d\d).*(\d\d\d\d)$/$1**$2/;
		  $::Session->{'CardRef'} = $cardref;
		}
#::logDebug("HSBC".__LINE__.": cardref=$cardref; $::Session->{CardRef}");

	my $fname        = $::Values->{'fname'} || $actual->{'b_fname'} || $actual->{'fname'};
	   $fname 		 =~ s/[^a-zA-Z0-9,.\- ]//gi;
	my $lname        = $::Values->{'lname'} || $actual->{'b_lname'} || $actual->{'lname'};
	   $lname		 =~ s/[^a-zA-Z0-9,.\- ]//gi;
	my $cardholder   = $::Values->{'cardholdername'} || "$fname $lname";
	   $cardholder   =~ s/[^a-zA-Z0-9,.\- ]//gi;
#::logDebug("HSBC".__LINE__.": name=$cardholder, $::Values->{cardholdername}; lname=$lname, $::Values->{lname}");
	my $mvccexpmonth  = sprintf '%02d', $actual->{'mv_credit_card_exp_month'};
	my $mvccexpyear   = sprintf '%02d', $actual->{'mv_credit_card_exp_year'};

	my $cardexpiration = $mvccexpmonth . "/" . $mvccexpyear;
	my $cardexpirationtds = $mvccexpyear . $mvccexpmonth;

	my $mvccstartmonth = sprintf '%02d', $actual->{'mv_credit_card_start_month'} || $::Values->{'mv_credit_card_start_month'} || $::Values->{'start_date_month'};
	   $mvccstartmonth =~ s/\D//g;
	
	my $mvccstartyear = $actual->{'mv_credit_card_start_year'} || $::Values->{'mv_credit_card_start_year'} || $::Values->{'start_date_year'};
	   $mvccstartyear =~ s/\D//g;
	   $mvccstartyear =~ s/\d\d(\d\d)/$1/;
	   
	my $startdate = $mvccstartmonth . "/" . $mvccstartyear;
	   $startdate = '' unless $mvccstartmonth > '0';

	my $issuenumber = $actual->{'mv_credit_card_issue_number'} || $::Values->{'mv_credit_card_issue_number'} ||  $::Values->{'card_issue_number'};
	   $issuenumber =~ s/\D//g;
	
	my $cv2  =  $actual->{'mv_credit_card_cvv2'} || $::Values->{'cvv2'};
	   $cv2  =~ s/\D//g;
	   
	my $cv2indicator = $::Values->{'cv2indicator'} || '2'; # 1=cv2 present, 2=cv2 customer claims not present on card, 5=intentionally not entered
	   $cv2indicator = '1' if length $cv2;
	   $::Session->{'cv2indicator'} = $cv2indicator if length $cv2;
#::logDebug("HSBC".__LINE__.": amt=$amount; currency=$currency; pan=$pan; cardholder=$cardholder; expm=$mvccexpmonth; expy=$mvccexpyear; issue=$issuenumber; cv2=$cv2; cv2indi=$cv2indicator; address=$address");


# Lookup unlisted iso codes from country.txt - major country and currency codes identical
	my ($iso_country_code_numeric, $iso_currency_code_numeric, $iso_currency_symbol, $currencyexponent); 

	if ($currency =~ /GBP/i) {
		$iso_currency_code_numeric = '826';
		$iso_currency_symbol = '&pound;';
		$currencyexponent = '2';
		}
	elsif ($currency =~ /EUR/i) {
		$iso_currency_code_numeric = '978';
		$iso_currency_symbol = '&euro;';
		$currencyexponent = '2';
		}
	elsif ($currency =~ /USD/i) {
		$iso_currency_code_numeric = '840';
		$iso_currency_symbol = '$';
		$currencyexponent = '2';
		}
	elsif ($currency =~ /AUD/i) {
		$iso_currency_code_numeric = '036';
		$iso_currency_symbol = '$';
		$currencyexponent = '2';
		}
	elsif ($currency =~ /CAD/i) {
		$iso_currency_code_numeric = '124';
		$iso_currency_symbol = '$';
		$currencyexponent = '2';
		}
	elsif ($currency =~ /DKK/i) { 
		$iso_currency_code_numeric = '206';
		$iso_currency_symbol = 'kr';
		$currencyexponent = '2';
		}
	elsif ($currency =~ /HKD/i) {
		$iso_currency_code_numeric = '344';
		$iso_currency_symbol = '$';
		$currencyexponent = '2';
		}
	elsif ($currency =~ /JPY/i) {
		$iso_currency_code_numeric = '392';
		$iso_currency_symbol = 'Y';
		$currencyexponent = '0';
		}
	elsif ($currency =~ /NZD/i) {
		$iso_currency_code_numeric = '554';
		$iso_currency_symbol = '$';
		$currencyexponent = '2';
		}
	elsif ($currency =~ /NOK/i) { 
		$iso_currency_code_numeric = '578';
		$iso_currency_symbol = 'kr';
		$currencyexponent = '2';
		}
	elsif ($currency =~ /SGD/i) { 
		$iso_currency_code_numeric = '702';
		$iso_currency_symbol = '$';
		$currencyexponent = '2';
		}
	elsif ($currency =~ /SEK/i) { 
		$iso_currency_code_numeric = '752';
		$iso_currency_symbol = 'kr';
		$currencyexponent = '2';
		}
	elsif ($currency =~ /CHF/i) {
		$iso_currency_code_numeric = '756';
		$iso_currency_symbol = 'CHF';
		$currencyexponent = '2';
		}

	if ($country =~ /GB|UK/i) {
		$iso_country_code_numeric = '826';
		}
	elsif ($country =~ /US/i) {
		$iso_country_code_numeric = '840';
		}
	else {
	    $db  = dbref('country') || die ::errmsg("cannot open country table");
	    $dbh = $db->dbh() || die ::errmsg("cannot get handle for tbl 'country'");
	    $sth = $dbh->prepare("SELECT isonum FROM country WHERE code = '$country'");
		$sth->execute();
		$iso_country_code_numeric = $sth->fetchrow();		
	};

#::logDebug("HSBC".__LINE__.": country=$country; currency=$currency; currencycode=$iso_currency_code_numeric; countrycode=$iso_country_code_numeric");
		$iso_currency_code_numeric = '826' unless defined $iso_currency_code_numeric;
		$iso_country_code_numeric  = '826' unless defined $iso_country_code_numeric;
#::logDebug("HSBC".__LINE__.": cardref=$cardref; req=$hsbcrequest;  country=$country; currency=$currency; currencycode=$iso_currency_code_numeric");
#::logDebug("HSBC".__LINE__.": usebill=$usebill; country: $::Values->{b_country}, $actual->{b_country}; $::Values->{country}, $actual->{country}");

#------------------------------------------------------------------------------------------------
# Go to PaymentAuthenticationServer first, before posting to bank, if doing 3DSecure
#
	if ($hsbcrequest eq 'tdspost') {
#::logDebug("HSBC".__LINE__." started 3DS post to PAS $tdshost");
# now create encoded string to have returned with data for next post to gateway
	$md = encode_base64("$pan:$cv2:$cv2indicator:$cardexpiration:$issuenumber:$amount:$x");

		$::Session->{'tdshost'} = $::Scratch->{'tdshost'}  = $tdshost;
		$::Scratch->{'cardexpiration'}   = $cardexpirationtds;
		$::Scratch->{'cardholderpan'} = $pan;
		$::Scratch->{'ccpaclientid'}  = $ccpaclientid;
		$::Scratch->{'currencyexponent'} = $currencyexponent;
		$::Scratch->{'md'} = $md;
		$::Scratch->{'purchaseamount'}  = $iso_currency_symbol . $purchaseamount;
		$::Scratch->{'purchaseamountraw'}  = $amount;
		$::Scratch->{'purchasecurrency'}  = $iso_currency_code_numeric;
		$::Scratch->{'resulturl'}  = $returnurl;
		
		$::Scratch->{'issuenumber'} = $issuenumber;

	$::Scratch->{'tdsreturned'} = $::Scratch->{'tdsbounced'} = '';
	
	$::Scratch->{'tdsrun'} = $::Scratch->{'tdspause'} = '1';
#::logDebug("HSBC".__LINE__.": cursymbol=$iso_currency_symbol; pamnt=$purchaseamount; curcode=$iso_currency_code_numeric");	
	my $hsbctds = $Tag->area({ href => "$hsbctdspage" });
#::logDebug("HSBC".__LINE__." tdshost=$::Scratch->{'tdshost'}, $tdshost; returnurl=$returnurl; tdspage=$hsbctdspage; tds=$hsbctds");
$Tag->tag({ op => 'header', body => <<EOB });
Status: 302 moved
Location: $hsbctds
EOB

	 }

#----------------------------------------------------------------------------------------------
# Header for use in gwpost or other ops
#

	my $header = <<EOX;
<?xml version="1.0" encoding="UTF-8" ?> 
  <EngineDocList>
    <DocVersion DataType="String">1.0</DocVersion>
    <EngineDoc>
      <ContentType DataType="String">OrderFormDoc</ContentType>
      <User>
        <ClientId DataType="S32">$clientid</ClientId>
        <Name DataType="String">$username</Name>
        <Password DataType="String">$password</Password>
       </User>
EOX


#----------------------------------------------------------------------------------------------------------
# Returned from the PAS - read results from PAS and action accordingly
#

	if ($hsbcrequest eq 'gwpost') {
#::logDebug("HSBC".__LINE__." started $hsbcrequest; tdsreturn=$tdsreturn");

# Result from PAS is posted as key=val pairs in URL. Run this only if doing 3DS
	if ($tdsreturn) {
	  my $tdsdata = ::http()->{entity} ;
	  my @tdsresult = split(/&/, $$tdsdata);
#::logDebug("HSBC".__LINE__.": tdsresult=@tdsresult; back=$$tdsdata");	
	  foreach (@tdsresult) {
		my($key,$val) = split(/=/,$_);
		$result{$key} = $val;
#::logDebug("HSBC".__LINE__.": tdsresult: $key = $val");
	  }
#::logDebug("HSBC".__LINE__." result from PAS:" .::uneval(\%result));

	undef $result{'MErrMsg'};

# If PAS 3DSecure result is OK then post to gateway
# Simply post directly to 'gwpost' and not 'tdspost' if you want to bypass 3DSecure
# Set various values according to the CcpaResultsCode
 	if ($result{'CcpaResultsCode'} =~ /5|6/) {
#::logDebug("HSBC".__LINE__.": 	code=$result{'CcpaResultsCode'}");
	$result{'MErrMsg'} = "Authentication failed, please try again or use a different card";
	return(%result);
	}
	elsif ($result{'CcpaResultsCode'} == '10') {
	$result{'MErrMsg'} = "Payment error, please try again or use a different method";
	return(%result);
	}

    elsif ($result{'CcpaResultsCode'} == '0'){
		$result{'PayerSecurityLevel'} = '2';
		$result{'PayerAuthenticationCode'} = $result{'CAVV'};
		$result{'PayerTxnId'} = $result{'XID'};
		$result{'CardholderPresentCode'} = '13';
	}
	elsif ($result{'CcpaResultsCode'} == '1') {
		$result{'PayerSecurityLevel'} = '5';
		$result{'CardholderPresentCode'} = '13';
	
	}
	elsif ($result{'CcpaResultsCode'} == '2') {
		$result{'PayerSecurityLevel'} = '1';
		$result{'CardholderPresentCode'} = '13';
	}
	elsif ($result{'CcpaResultsCode'} == '3') {
		$result{'PayerSecurityLevel'} = '6';
		$result{'PayerAuthenticationCode'} = $result{'CAVV'};
		$result{'PayerTxnId'} = $result{'XID'};
		$result{'CardholderPresentCode'} = '13';
	}
	elsif ($result{'CcpaResultsCode'} == '14') {
		$result{'CardholderPresentCode'} = '7';
	}
	else {
		$result{'PayerSecurityLevel'} = '4';
	}
# end after PAS results parsed
	$md = decode_base64($result{'MD'});
	($pan,$cv2,$cv2indicator,$cardexpiration,$issuenumber,$amount,$x) = split /:/, $md;

#::logDebug("HSBC".__LINE__." pan=$pan, cv2=$cv2, cv2ind=$cv2indicator, sid=$::Session->{id}; scpan=$::Scratch->{'cardholderpan'}");
	$pan ||= $::Scratch->{'cardholderpan'};


	} # if tdsreturn

	undef %result unless length $tdsreturn;

#::logDebug("HSBC".__LINE__." result from PAS after massage:" .::uneval(\%result));

	my $cardholderpresentcode = $result{'CardholderPresentCode'} || '7'; # 7 for initial setup without 3DS   $paymenttype = 'PaymentNoFraud' if $cardholderpresentcode =~ /8|10/;
	my $txid = $Tag->time({ body => "%Y%m%d%H%M%S" }) . $::Session->{id}; 
	   $txid = $::Values->{'txid'} if ($txtype =~ /^PostAuth|Void|^RePreAuth|^ReAuth|Credit/i and !$pan);
			   $::Values->{'txid'} = '';
	my $grouptxid = "rp-" . $txid unless $::Values->{'grouptxid'}; # Pull from db on repeats, else generate for first instance of periodic billing
			   $::Values->{'grouptxid'} = '';
   #	$order_id .= $::Session->{id};
	    $::Session->{'order_id'} = $txid;
		$::Session->{'HSBCHost'} = '';
		$::Scratch->{'tdspause'} = '';
#::logDebug("HSBC".__LINE__.": pan=$pan, cv2=$cv2; exp=$cardexpiration, amnt=$amount; txid=$txid; rpordernumer=$::Values->{rpordernumber}; chpcode=$cardholderpresentcode");

		$cv2 ||= $::Scratch->{'cv2'};
		$issuenumber ||= $::Scratch->{'issuenumber'};
#::logDebug("HSBC".__LINE__.": amt=$amount; pan=$pan; cardholder=$cardholder; fname=$fname, lname=$lname, cv2=$cv2; cv2indi=$cv2indicator; address=$address");

   my $xmlOut = $header;
   
	  $xmlOut .= <<EOX;   
      <Instructions>
        <Pipeline DataType="String">$paymenttype</Pipeline>
      </Instructions>
      <OrderFormDoc>
        <Id DataType="String">$txid</Id>
        <Mode DataType="String">$txmode</Mode>
EOX

	   $xmlOut .= <<EOX unless $txtype =~ /void|credit|postauth/i;
         <Consumer>
			<BillTo>
			  <Location>
				<TelVoice>$telephone</TelVoice>
				<Email>$email</Email>
				<Address>
				  <Title></Title>
				  <FirstName>$fname</FirstName>
				  <LastName>$lname</LastName>
				  <Name>$cardholder</Name>
EOX

		$xmlOut .= <<EOX if $paymenttype eq 'Payment';
				  <Street1>$address1</Street1>
				  <Street2>$address2</Street2>
				  <Street3>$address3</Street3>
				  <City>$city</City>
				  <StateProv>$state</StateProv>
				  <PostalCode>$zip</PostalCode>
				  <Country>$iso_country_code_numeric</Country>
EOX

		$xmlOut .= <<EOX unless $txtype =~ /void|credit|refund|postauth/i;
				</Address>
			  </Location>
			</BillTo>
          <PaymentMech>
            <Type DataType="String">CreditCard</Type>
             <CreditCard>
              <Number DataType="String">$pan</Number>
              <Expires DataType="ExpirationDate" Locale="$iso_country_code_numeric">$cardexpiration</Expires>
EOX

	  $xmlOut .= <<EOX if $startdate;
			  <StartDate DataType="StartDate" Locale="$iso_country_code_numeric">$startdate</StartDate>
EOX
# for 'credit' as payment to card, rather than 'credit' as refund to txid
#            <Type DataType="String">CreditCard</Type>
	  $xmlOut .= <<EOX if ($txtype =~ /credit/i and length $pan);
		<Consumer>
          <PaymentMech>
             <CreditCard>
              <Number DataType="String">$pan</Number>
              <Expires DataType="ExpirationDate" Locale="$iso_country_code_numeric">$cardexpiration</Expires>
             </CreditCard>
          </PaymentMech>
		</Consumer>
EOX

	  $xmlOut .= <<EOX unless $txtype =~ /void|credit|refund|postauth/i;
			  <Cvv2Indicator>$cv2indicator</Cvv2Indicator>
			  <Cvv2Val>$cv2</Cvv2Val>
			  <IssueNum>$issuenumber</IssueNum>
           </CreditCard>
          </PaymentMech>
        </Consumer>
EOX
	  $xmlOut .= <<EOX;
        <Transaction>
          <Type DataType="String">$txtype</Type>
EOX

	  $xmlOut .= <<EOX  unless $txtype =~ /void|credit|postauth/i;
	      <CardholderPresentCode>$cardholderpresentcode</CardholderPresentCode>
EOX

       $xmlOut .= <<EOX if $result{'XID'};
		  <PayerAuthenticationCode>$result{'CAVV'}</PayerAuthenticationCode>
		  <PayerTxnId>$result{'XID'}</PayerTxnId>
		  <PayerSecurityLevel>$result{'PayerSecurityLevel'}</PayerSecurityLevel>
EOX

	   $xmlOut .= <<EOX if $authcode;
		  <AuthCode>$authcode</AuthCode>
EOX

	  
	   $xmlOut .= <<EOX unless $txtype =~ /void|postauth/i;
          <CurrentTotals>
            <Totals>
              <Total DataType="Money" Currency="$iso_currency_code_numeric">$amount</Total>
            </Totals>
          </CurrentTotals>
EOX

		$xmlOut .= <<EOX;
        </Transaction>
EOX

	 $xmlOut .= <<EOX;
      </OrderFormDoc>
    </EngineDoc>
  </EngineDocList>	  
EOX

#::logDebug("HSBC".__LINE__.": xmlOut=$xmlOut");
	my $msg = postHSBC($xmlOut);
#::logDebug("HSBC".__LINE__.": msg returned=$msg");	
	my $xml = new XML::Simple(Keyattr => 'EngineDocList');
	my $data = $xml->XMLin("$msg");
	   $data = $data->{'EngineDoc'}{'OrderFormDoc'};
#::logDebug("HSBC".__LINE__.": xmlback=".::uneval($data));

#::logDebug("HSBC".__LINE__.": MErrMsg=$result{'MErrMsg'}");		
#::logGlobal("HSBC: msg returned=$msg") if $result{'CcErrCode'} != '1';	
	   $result{'TxStatus'} = $data->{'Overview'}{'TransactionStatus'};
	   $result{'TxType'} = $txtype;
	   $result{'CardRef'} = $::Session->{'CardRef'};
	   $result{'Currency'} = $currency if length $currency;
 
	   $result{'HSBCTxId'} = $data->{'Transaction'}{'Id'}{'content'};
	   $result{'SecurityIndicator'} = $data->{'Transaction'}{'SecurityIndicator'}{'content'};
	   $result{'AuthCode'} = $data->{'Transaction'}{'AuthCode'}{'content'};
	   $result{'Type'} = $data->{'Transaction'}{'Auth'}{'content'};
	   $result{'SendRPvsData'} = $data->{'Transaction'}{'SendPbAvsData'}{'content'};
	   $result{'ProcReturnMsg'} = $data->{'Transaction'}{'CardProcResp'}{'ProcReturnMsg'}{'content'};
	   $result{'ProcReturnCode'} = $data->{'Transaction'}{'CardProcResp'}{'ProcReturnCode'}{'content'};
	   $result{'Status'} = $data->{'Transaction'}{'CardProcResp'}{'Status'}{'content'};
	   $result{'CcErrCode'} = $data->{'Transaction'}{'CardProcResp'}{'CcErrCode'}{'content'};
	   $result{'CcReturnMsg'} = $data->{'Transaction'}{'CardProcResp'}{'CcReturnMsg'}{'content'};
	   $result{'ProcAvsRespCode'} = $data->{'Transaction'}{'CardProcResp'}{'ProcAvsRespCode'}{'content'};
	   $result{'AvsDisplay'} = $data->{'Transaction'}{'CardProcResp'}{'AvsDisplay'}{'content'};
	   $result{'CcReturnMsg'} = $data->{'Transaction'}{'CardProcResp'}{'CcReturnMsg'}{'content'};
	   $result{'CommercialCardType'} = $data->{'Transaction'}{'CardProcResp'}{'CommercialCardType'}{'content'};
	   $result{'Cvv2Resp'} = $data->{'Transaction'}{'CardProcResp'}{'Cvv2Resp'}{'content'};
	   $result{'FraudStatus'} = $data->{'Overview'}{'FraudStatus'}{'content'};
	   $result{'FraudResult'} = $data->{'FraudInfo'}{'FraudResult'}{'content'};
	   $result{'FraudOrderScore'} = $data->{'FraudInfo'}{'OrderScore'}{'content'};

	   $pass = '1' if $result{'CcErrCode'} == '1'; # no errors, full pass

# Multiple triggers of fraud rules: fail if one rule fails	
	  if ($pass != '1') {
	   if ($data->{'FraudInfo'}{'Alerts'} =~ /ARRAY/i) {
		 for my $i (0 .. 3) {
		  $result{'FraudRuleId'} = $data->{'FraudInfo'}{'Alerts'}[$i]{'RuleId'}{'content'};
		  $result{'FraudMsg'} = $data->{'FraudInfo'}{'Alerts'}[$i]{'Message'}{'content'};
		  $pass = '';
		  $pass = '1' if charge_param('fraud_' . $result{'FraudRuleId'}) =~ /1/;
		  $display .= " \"$result{'FraudMsg'}\" <br>" if charge_param('fraud_' . $result{'FraudRuleId'}) =~ /2/;
			  last if $pass != '1';
				  }
				}
		 else {
		  $result{'FraudRuleId'} = $data->{'FraudInfo'}{'Alerts'}{'RuleId'}{'content'};
		  $result{'FraudMsg'} = $data->{'FraudInfo'}{'Alerts'}{'Message'}{'content'};
		  $pass = '1' if charge_param('fraud_' . $result{'FraudRuleId'}) =~ /1/; # list of all rule IDs plus descriptions
		  $display = " \"$result{'FraudMsg'}\" " if charge_param('fraud_' .$result{'FraudRuleId'}) =~ /2/; # display the message
		  }
		}
	    
	   $result{'FraudTotalScore'} = $data->{'FraudInfo'}{'TotalScore'}{'content'};
	   $result{'FraudResultCode'} = $data->{'FraudInfo'}{'FraudResultCode'}{'content'};
	   $result{'CardholderPresentCode'} = $data->{'Transaction'}{'CardholderPresentCode'}{'content'};
#::logDebug("HSBC".__LINE__.": status=$result{'TxStatus'}; authcode=$result{'AuthCode'}; errorcode=$result{CcErrCode}");

	my $hsbcdate = $Tag->time({ body => "%A %d %B %Y, %k:%M:%S, %Z" });
	my $amountshow =  $amount/'100';

#
#-------------------------------------------------------------------------------------------------
# Now to complete things
#

#::logDebug("HSBC".__LINE__.": rule=$result{FraudRuleId}; ReturnMsg=$result{'CcReturnMsg'}");
	 $display =~ s/Select \'Accept\' to proceed with the order\.//gi;
	 $display =~ s/It is recommended that caution is exercised\.//gi;
	 $::Scratch->{'pspfraudmsg'} = '';
#::logDebug("HSBC".__LINE__.": ErrCode=$result{CcErrCode}; MStatus=$result{MStatus}; SecureStatus=$result{'SecureStatus'}");
  if (($pass == '1') and ($hsbcrequest eq 'gwpost')) {
         $result{'MStatus'} = 'success';
		 $result{'pop.status'} = 'success';
		 $::Scratch->{'mstatus'} = 'success';
         $result{'order-id'} ||= $::Session->{'order_id'};
		 $::Values->{'mv_payment'} = "Real-time card $::Session->{'CardInfo'}";
		  if (length $tdsreturn) {
		   undef $tdsreturn; 
		   $::Values->{'psp'} = charge_param('psp') || 'HSBC';
   		   $::Session->{'payment_id'} = $result{'order-id'};
		   $::Scratch->{'order_id'} = $result{'order-id'};
		   $::CGI::values{'mv_todo'} = 'submit';
		   $::Scratch->{'tdsrun'} = '1';
#::logDebug("HSBC".__LINE__.": result=".::uneval(\%result));
		   $::Scratch->{'pspfraudmsg'} = "Our bank has flagged this transaction, " 
					  . $display . 
					  " and we are obligated to review this order prior to accepting payment
						and making despatch. Our apologies for any inconvenience." 
							if $result{'CcErrCode'} != '1';

					$Vend::Session->{'payment_result'} = \%result;
					Vend::Dispatch::do_process();

					}
			  }
   else  {
         $result{'MStatus'} = $result{'pop.status'} = $::Scratch->{'mstatus'} = 'fail';
         $result{'order-id'} = $result{'pop.order-id'} = '';
         $result{'MErrMsg'} = 'Order not taken, card problem. ' . $display; 
#::logDebug("HSBC".__LINE__.": mstatus=$result{'MStatus'}; MErrMsg=$result{'MErrMsg'}"); 
	}

	# my $review = $result{'OverView'}{'FraudStatus'} || $result{'OverView'}{'FraudStatus'} 
#::logDebug("HSBC".__LINE__.": fraudstatus=$result{'FraudStatus'}");
		if ($result{'FraudStatus'} =~ /Review/i) {
		$mailreview = <<EOM;
At $hsbcdate, HSBC TxID $result{HSBCTxId},  for 
$result{Currency} $amountshow has been marked both "$result{ProcReturnMsg}" and 
"$result{CcReturnMsg}" with ErrorCode "$result{CcErrCode}". 
EOM

		$::Tag->email({ to => $mailto, from => $mailto, reply => $mailto,
						subject => "HSBC txn: blocked for fraud review",
						body => "$mailreview\n\n",
					  });
#::logDebug("HSBC".__LINE__.": blocked, now to mail: $mailreview");
		};
	
		if (($result{'FraudStatus'} =~ /Decline/i) and (charge_param('mail_txn_declined') == '1')) {
		$::Tag->email({ to => $mailto, from => $mailto, reply => $mailto,
						subject => "HSBC txn: declined",
						body => "$mailreview\n\n",
					  });
#::logDebug("HSBC".__LINE__.": declined, now to mail: $mailreview");
		};
		
		$mailtxn = "At $hsbcdate you received payment from $cardholder of
$result{Currency}$amountshow for OrderID $::Session->{'payment_id'}, HSBC txn ID $result{HSBCTxId},
 AuthCode $result{AuthCode}, from IP $ipaddress with card $result{CardBrand} $result{CardRef}";

		if (($result{'CcReturnMsg'} =~ /Approved/i) and (charge_param('mail_txn_approved') == '1')) {
		$::Tag->email({ to => $mailto, from => $mailto, reply => $mailto,
						subject => "HSBC txn: approved",
						body => "$mailtxn\n\n",
					  });
#::logDebug("HSBC".__LINE__.": approved, now to mailto $mailto: $mailtxn");
		};

#::logDebug("HSBC".__LINE__.": result=".::uneval(\%result));
		return (%result);

 	} # if gwpost

}

#
#--------------------------------------------------------------------------------------------------
# End of main routine
#--------------------------------------------------------------------------------------------------
#

sub postHSBC {
	 my $self = shift;
#::logDebug("HSBC".__LINE__."\n###############\nxmlout=$self\n================\n");
	 my $ua = LWP::UserAgent->new;
	    $ua->timeout(30);
	 my $req = HTTP::Request->new('POST' => $gwhost);
		$req->content_type('text/xml');
		$req->content_length( length($self) );
		$req->content($self);
	 my $res = $ua->request($req);
	 my $respcode = $res->status_line;

	if ($res->is_success && $res->content){
		return ($res->content());
			  }
	else {
		$::Session->{'errors'}{'HSBC'} = "No response from the HSBC payment gateway";
		return $res->status_line;
     }
}

package Vend::Payment::HSBC;

1;
