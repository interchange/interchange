# Vend::Payment::Cardsave - Interchange Cardsave Payment module
#
# Copyright (C) 2012 Zolotek Resources Ltd
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
package Vend::Payment::Cardsave;

=head1 NAME

Vend::Payment::Cardsave - Interchange Cardsave Payments Module

=head1 PREREQUISITES

    XML::Simple
    URI
    libwww-perl
    Net::SSLeay
	HTTP::Request
	
Test for current installations, eg: perl -MXML::Simple -e 'print "It works\n"'
To install perl modules do: "emerge dev-perl/XML-Simple" on Gentoo, or on other systems do
"perl -MCPAN -e  'install XML::Simple'"

=head1 DESCRIPTION

The Vend::Payment::Cardsave module implements the Cardsave payment routine for use with Interchange.

#=========================

=head1 SYNOPSIS

Quick start:

Place this module in <ic_root>/lib/Vend/Payment, and call it in <ic_root>/interchange.cfg with
Require module Vend::Payment::Cardsave. Ensure that your perl installation contains the modules
listed above and their pre-requisites.

Add a new payment route into catalog.cfg as follows:
Route cardsave id xxx
Route cardsave password xxx
Route cardsave returnurl 'https://domain.tld/cgi/ord/tdscardsavereturn'

The above are required, while those below are only required if you want to change from the 
default values as noted. These may be overriden at run-time with: [value avs_override_policy].
[value cv2_override_policy] and [value tds_override_policy] respectively.

Route cardsave avsoverridepolicy NPPP
Route cardsave cv2overridepolicy PP
Route cardsave threedsecureoverridepolicy TRUE

These next are also optional and allow you to override the default error messages as given in parentheses
with your own error messages to display to errant customers:
Route cardsave main3DSerror (Payment error: )
Route cardsave address_error (Address match failed)
Route cardsave postcode_error (PostalCode match failed)
Route cardsave cv2_error  (Card Security Code match failed)
The displayed message will start with the main3DSerror and append others as appropriate. 
Route cardsave mail_txn_to (email address, defaults to ORDERS_TO)
Route cardsave mail_txn_approved (1 to email approved orders)
Route cardsave mail_txn_declined (1 to email possibly fraudulent attempts)

Alter etc/log_transaction to wrap the following code around the "[charge route...]" call 
found in ln 172 (or nearby):
	[if scratchd mstatus eq success]
	[tmp name="charge_succeed"][scratch order_id][/tmp]
	[else]
	[tmp name="charge_succeed"][charge route="[var MV_PAYMENT_MODE]" amount="[scratch tmp_remaining]" order_id="[value mv_transaction_id]"][/tmp]
	[/else]
	[/if]
and change [var MV_PAYMENT_MODE] above to [value mv_payment_route] if you want to use Paypal or similar in conjunction with this

Also add these lines just after '&final = yes' near the end of the credit_card section of etc/profiles.order:
&set=mv_payment Cardsave
&set=psp Cardsave
&set=mv_payment_route cardsave
&set=mv_order_route default
&setcheck = end_profile 1
&setcheck = payment_method cardsave

New fields to put into the transactions table:
psp: [value psp] (type varchar(64))
payment_route: [value mv_payment_route] (type varchar(128))
txtype:  [calc]$Session->{payment_result}{TxType} || $Scratch->{txtype};[/calc] (type varchar(64))
pares: [calc]$Session->{payment_result}{PaRes};[/calc] (type text)
md: [calc]$Session->{payment_result}{MD};[/calc]  (type varchar(128))
currency_locale: [scratch mv_locale] (type varchar(64))
currency_code: [calc]$Session->{payment_result}{Currency};[/calc] (type varchar(32))
	
NB/ the country code and currency code are both numeric, not alphabetic, and are both '826';
The amount passed to Cardsave is in pennies, so £8.24 is passed as 824.

The card type and card issuer are both available from a special call, and this call is made prior
to the main transaction call. Both values are logged and may be of use in anti-fraud measures.

There are 2 gateway entry points listed, and each gateway entry point
is tried in turn until one responds, with a 30 second time-out on each. The one that responds on the first
'cardpost' call is put in session to become the default for the second call after returning from the ACS.
These "gateway entry points" are actually separate data centres, with hot replication between them, though 
the replication may take a minute or so - hence the preference to stay with the same gateway entrypoint 
throughout the entire transaction if possible. 

Create a page in pages/ord called tdscardsavereturn.html like so:
<html>
<head>
<link rel="stylesheet" href="/images/theme_css.css">
</head>
<body>
[charge route="cardsave" cardsaverequest="tdspost"]
(some blurb for those who failed at the ACS and thus don't get past the [charge ..] line above)
</body>
</html>

Create a page in pages/ord called tdsfinal.html, which includes this snippet
 	  <tr>
		<td align=center height=600 valign=middle colspan=2 width=800>
		  <iframe src="[area ord/tdsauth]"  frameborder=0 width=800 height=600></iframe>
		</td>
	  </tr>
amongst the standard page elements, so the iframe is populated by the bank's ACS page.

Create another page in pages/ord called tdsauth.html like so:
<table align="center" width="100%">
 <tr>
  <td>
<body onload="document.form.submit();">
<FORM name="form" action="[scratchd acsurl]" method="POST" />
<input type="hidden" name="PaReq" value="[scratch pareq]" />
<input type="hidden" name="TermUrl" value="[scratch termurl]" />
<input type="hidden" name="MD" value="[scratch md]" />
</form>
<div style="background:white;border:1px solid blue;">
<br>
<noscript>
(equivalent form and a blurb for the customer to manually click 'submit')
</noscript>
  </td>
 </tr>
</table>
This page will be replaced by the bank's ACS page automagically. If the transaction is
successful at the bank, the customer will see the bank page replaced with the receipt page. 

In the etc/receipt.html page, change the calls to the header and footer like so:
[if type=explicit compare=`$Session->{payment_result}{SecureStatus} eq 'OK'`]
[else]
@_NOLEFT_TOP_@
[/else]
[/if]
[if type=explicit compare=`$Session->{payment_result}{SecureStatus} eq 'OK'`]
[else]
@_NOLEFT_BOTTOM_@
[/else]
[/if]
so that the receipt page will display properly within the tdsfinal page.

Test card numbers:
without 3DS: 4976000000003436/452 : street no 32 , postcode TR148PA, exp 12/12 gives 'success'
with 3DS: 4976350000006891/341, street no 113, postcode B421SX, exp 12/12 gives 'success'
other cv2s or postcodes should result in failure.

Virtual terminal operations:
Possible ops are: REFUND, COLLECTION, VOID, SALE, PREAUTH.
These are all keyed to the value of the MD returned from the original 3DSecure transaction
and saved into the transactions table as 'md'. This is read into the module as [value crossreference].
The various ops are read in as [value txtype]. The currency code is taken from the db and
read in as [value iso_currency_code_numeric], defaulting to '826' for GBP. 
SALE is used for repeat or recurring billing.

A possible block of code in a virtual terminal would be this:
<input type="hidden" name="mv_payment_route" value="cardsave">
<input type="hidden" name="cardsaverequest" value="crossreferencepost">
<input type="hidden" name="crossreference" value="[sql-param md]">
<select name="txtype">
  <option value="PREAUTH" "[selected txtype PREAUTH]">PreAuth
  <option value="REFUND" "[selected txtype REFUND]">Refund
  <option value="SALE" "[selected txtype SALE]">Sale
  <option value="COLLECTION" "[selected txtype COLLECTION]">Collection
  <option value="VOID" "[selected txtype VOID]">Void
</select>



=head1 Changelog
090: release candidate

098: following the split of LloydsTSB into two separate banks and the issue of new cards,
apparently using Royal Bank of Scotland BIN ranges, Cardsave are returning the issuer for
these cards only as a string whereas all other issuers are returned as a hash, contrary
to their API. This update handles that situation. 


=head1 AUTHORS

Lyn St George <lyn@zolotek.net>

=cut

BEGIN {
	eval {
		package Vend::Payment;
		require Net::SSLeay;
			require XML::Simple;
			require LWP;
			require HTTP::Request::Common;
			import HTTP::Request::Common qw(POST);
			use HTTP::Request  ();

	};

       $Vend::Payment::Have_LWP = 1 unless $@;

	if ($@) {
		$msg = __PACKAGE__ . ' requires XML::Simple, HTTP::Request, Net::SSLeay and LWP. ' . $@;
		::logGlobal ($msg);
		die $msg;
	}

	::logGlobal("%s v0.9.8 20130730 payment module loaded",__PACKAGE__)
		unless $Vend::Quiet or ! $Global::VendRoot;
}

package Vend::Payment;

use strict;

  my ($host, $host1, $host2, $host3, $host4);

sub cardsave {
    my ($response, $in, $opt, $actual, %result, $passoutdata, $orderdescription, $db, $dbh, $sth);
    my $subtotal = Vend::Interpolate::subtotal();
#::logDebug("TDSbounced=$::Scratch->{tdsbounced}; subtotal=$subtotal");
    return if ($::Scratch->{'tdsbounced'} > '1');

	my (%actual) = map_actual();
		$actual  = \%actual;

	my $cardsaverequest = charge_param('cardsaverequest') || $::Values->{'cardsaverequest'} || 'cardpost'; 
	   $::Values->{'tdsrequest'} = $cardsaverequest;
	if ($cardsaverequest eq 'cardpost') {
	   $result{'MErrMsg'} = "No credit card entered " unless $actual->{'mv_credit_card_number'};
	   $result{'MErrMsg'} .= "<br>No items in your basket " unless $subtotal > '0';
	 }
    
    return(%result) if length $result{'MErrMsg'};

#::logDebug("Cardsave".__LINE__.": txtype=$::Values->{txtype}; req=$::Values->{cardsaverequest};$cardsaverequest");
	my $username     = charge_param('id') or die "No username id\n";
	my $password     = charge_param('password') or die "No password\n";
 	my $txtype       = charge_param('txtype') || $::Values->{'txtype'} || 'SALE';
	   $::Values->{'txtype'} ||= $txtype;
	my $tdsfinalpage = charge_param('tdsfinalpage') || 'ord/tdsfinal'; 
	my $termurl      = charge_param('returnurl') || "$::Variable->{SECURE_SERVER}$::Variable->{CGI_URL}/ord/tdscardsavereturn";
	# ISO currency code, from the page for a multi-currency site or fall back to config files.
	my $currency = $::Scratch->{'iso_currency_code'} || $::Values->{'currency_code'} || charge_param('currency') || 'GBP';
	my $currency2 = $currency;
	   $currency2 =~ /(\w\w)/i;
	   $currency2 = $1;
#::logDebug("Cardsave".__LINE__.": 1=" . $::Scratch->{'iso_currency_code'} . "2=" . $::Values->{'currency_code'} . "3=" . charge_param('currency'));
	my $amount =  charge_param('amount') || Vend::Interpolate::total_cost() || $::Values->{'amount'}; 
	   $amount =~ s/^\D*//g;
	   $amount =~ s/\s*//g;
	   $amount =~ s/,//g;
	   $amount =  sprintf '%.2f', $amount;
	   $amount =~ s/\.//g; # £10.00 becomes 1000 for Cardsave

	   $host1   = charge_param('host1') || 'https://gw1.cardsaveonlinepayments.com:4430';   
	   $host2   = charge_param('host2') || 'https://gw2.cardsaveonlinepayments.com:4430';   
	   $host3   = charge_param('host3') || 'https://gw3.cardsaveonlinepayments.com:4430';   
	   $host4   = charge_param('host4') || 'https://gw4.cardsaveonlinepayments.com:4430'; ### NB testing only  
	   
	my $address1 = $::Values->{'b_address1'} || $::Values->{'address1'};
	my $address2 = $::Values->{'b_address2'} || $::Values->{'address2'};
	my $address3 = $::Values->{'b_address3'} || $::Values->{'address3'};
	my $address4 = $::Values->{'b_address4'} || $::Values->{'address4'};
	my $address  = "$address1, $address2, $address3 $address4";
	   $address  =~ s/,\s+$//g;
	   $address  =~ s/[^a-zA-Z0-9,.\- ]//gi;
	my $city     = $::Values->{'b_city'} || $::Values->{'city'};
	   $city     =~ s/[^a-zA-Z0-9,.\- ]//gi;
	my $state    = $::Values->{'b_state'} || $::Values->{'state'};
	   $state    =~ s/[^a-zA-Z0-9,.\- ]//gi;
	my $zip      = $::Values->{'b_zip'} || $::Values->{'zip'};
	   $zip      =~ s/[^a-zA-Z0-9,.\- ]//gi;
	my $country  = $::Values->{'b_country'} || $::Values->{'country'};
	my $email      = $actual->{'email'};
	   $email      =~ s/[^a-zA-Z0-9.\@\-_]//gi;
	my $phone      = $actual->{'phone_day'} || $actual->{'phone_night'};
	   $phone      =~ s/[\(\)]/ /g;
	   $phone      =~ s/[^0-9-+ ]//g;
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
	my $cardref  = $pan;
	   $cardref  =~ s/^(\d\d\d\d).*(\d\d\d\d)$/$1****$2/;
	   $::Session->{'CardRef'} = $cardref;
	   
	my $cardholder         = "$actual->{b_fname} $actual->{b_lname}" || "$actual->{fname} $actual->{lname}";
	   $cardholder         =~ s/[^a-zA-Z0-9,.\- ]//gi;

	my $mvccexpmonth  = sprintf '%02d', $actual->{'mv_credit_card_exp_month'};
	my $mvccexpyear   = sprintf '%02d', $actual->{'mv_credit_card_exp_year'};

	my $expshow = "$mvccexpmonth" . "$mvccexpyear";
	   $expshow =~ s/(\d\d)(\d\d)/$1\/$2/;

	my $mvccstartmonth = $actual->{'mv_credit_card_start_month'} || $::Values->{'mv_credit_card_start_month'} || $::Values->{'start_date_month'};
	   $mvccstartmonth =~ s/\D//g;
	
	my $mvccstartyear = $actual->{'mv_credit_card_start_year'} || $::Values->{'mv_credit_card_start_year'} || $::Values->{'start_date_year'};
	   $mvccstartyear =~ s/\D//;
	   $mvccstartyear =~ s/\d\d(\d\d)/$1/;

	my $issuenumber = $actual->{'mv_credit_card_issue_number'} || $::Values->{'mv_credit_card_issue_number'} ||  $::Values->{'card_issue_number'};
	   $issuenumber =~ s/\D//g;
	
	my $cv2  =  $actual->{'mv_credit_card_cvv2'} || $::Values->{'mv_credit_card_cvv2'} || $::Values->{'cvv2'};
	   $cv2  =~ s/\D//g;
	   
	   $::Session->{'mv_order_number'} = $::Values->{'mv_order_number'};

#::logDebug("Cardsave".__LINE__.": on=$::Values->{mv_order_number}; valtxtype=$::Values->{txtype};  pan=$pan; cardholder=$cardholder; expm=$mvccexpmonth; expy=$mvccexpyear; issue=$issuenumber; cv2=$cv2; address=$address");

my $echocardtype = charge_param('echocardtype') || 'TRUE';
	my $echoavscheckresult = charge_param('echoavscheckresult') || 'TRUE';
	my $echocv2checkresult = charge_param('echocv2checkresult') || 'TRUE';
	my $echoamountreceived = charge_param('echoamountreceived') || 'TRUE';
	my $duplicatedelay = charge_param('duplicatedelay') || '1';
	my $avsoverridepolicy = delete $::Values->{'avs_override_policy'} || charge_param('avsoverridepolicy') || 'NPPP';
	my $cv2overridepolicy = delete $::Values->{'cv2_override_policy'} || charge_param('cv2overridepolicy') || 'PP';
	my $threedsecureoverridepolicy = delete $::Values->{'tds_override_policy'} || charge_param('threedsecureoverridepolicy') || 'TRUE'; # TRUE forces 3DS on, FALSE sets 3DS off
	my $mailto = charge_param('mail_txn_to') || $::Variable->{'ORDERS_TO'};

# Lookup iso code from country.txt - major country and currency codes identical
	my ($iso_country_code_numeric, $iso_currency_code_numeric); 
	    $db  = dbref('country') or die ::errmsg("cannot open country table");
	    $dbh = $db->dbh() or die ::errmsg("cannot get handle for tbl 'country'");
	    $sth = $dbh->prepare("SELECT isonum FROM country WHERE code = '$currency2'");

	if ($currency =~ /GBP/i) {
		$iso_currency_code_numeric = '826';
		}
	elsif ($currency =~ /EUR/i) {
		$iso_currency_code_numeric = '978';
		}
	elsif ($currency =~ /USD/i) {
		$iso_currency_code_numeric = '840';
		}
	else {
		$sth->execute();
		$iso_currency_code_numeric = $sth->fetchrow();		
	};

	if ($country =~ /GB|UK/i) {
		$iso_country_code_numeric = '826';
		}
	elsif ($country =~ /US/i) {
		$iso_country_code_numeric = '840';
		}
	else {
	    $sth = $dbh->prepare("SELECT isonum FROM country WHERE code = '$country'");
		$sth->execute();
		$iso_country_code_numeric = $sth->fetchrow();		
	};

#::logDebug("Cardsave".__LINE__.": country=$country,code=$iso_country_code_numeric; currency=$currency,cur2=$currency2; currencycode=$iso_currency_code_numeric");
		$iso_currency_code_numeric = '826' unless defined $iso_currency_code_numeric;
		$iso_country_code_numeric  = '826' unless defined $iso_country_code_numeric;
#::logDebug("Cardsave".__LINE__.": country=$country; currency=$currency; currencycode=$iso_currency_code_numeric");

#-------------------------------------------------------------------------------------------------
# Create the Header and the Transaction Control block for re-use
#
	my $header = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema"
               xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Body>
EOF

	my $transcontrol = <<EOF;
        <TransactionControl>
          <EchoCardType>$echocardtype</EchoCardType>
          <EchoAVSCheckResult>$echoavscheckresult</EchoAVSCheckResult>
          <EchoCV2CheckResult>$echocv2checkresult</EchoCV2CheckResult>
          <EchoAmountReceived>$echoamountreceived</EchoAmountReceived>
          <DuplicateDelay>$duplicatedelay</DuplicateDelay>
          <AVSOverridePolicy>$avsoverridepolicy</AVSOverridePolicy>
          <CV2OverridePolicy>$cv2overridepolicy</CV2OverridePolicy>
          <ThreeDSecureOverridePolicy>$threedsecureoverridepolicy</ThreeDSecureOverridePolicy>
        </TransactionControl>
EOF

#--------------------------------------------------------------------------------------------------
# Create a CardDetailsTransaction request and read response
#
	if ($cardsaverequest eq 'cardpost') {
#::logDebug("Cardsave".__LINE__." started $cardsaverequest; on=$::Values->{mv_order_number};");
#::logDebug("Cardsave".__LINE__.": result=".::uneval(\%result));

	 my $order_id  = $Tag->time({ body => "%Y%m%d%H%M%S" }); 
    	$order_id .= $::Session->{id};
	    $::Session->{'order_id'} = $order_id;
		$::Session->{'CardsaveHost'} = '$host1';
		$::Scratch->{'tdspause'} = '';
		$::Scratch->{'mstatus'} = '';
#        $::Scratch->{'tdsmsg'} = '';

#::logDebug("Cardsave".__LINE__.": txtype=$txtype; order-id=$order_id; soid=$::Scratch->{order_id}");

	my $xmlOut = $header;
	   $xmlOut .= <<EOX;
<CardDetailsTransaction xmlns="https://www.thepaymentgateway.net/">
    <PaymentMessage>
     <MerchantAuthentication Password="$password" MerchantID="$username" /> 
      <TransactionDetails Amount="$amount" CurrencyCode="$iso_currency_code_numeric">
        <MessageDetails TransactionType="$txtype" />
        <OrderID>$order_id</OrderID>
EOX

	$xmlOut .= $transcontrol;

	$xmlOut .= <<EOX;
	 </TransactionDetails>
	  <CardDetails>
        <CardName>$cardholder</CardName>
        <CardNumber>$pan</CardNumber>
        <ExpiryDate Month="$mvccexpmonth" Year="$mvccexpyear" />
        <StartDate Month="$mvccstartmonth" Year="$mvccstartyear" />
        <CV2>$cv2</CV2>
        <IssueNumber>$issuenumber</IssueNumber>
      </CardDetails>
      <CustomerDetails>
        <BillingAddress>
          <Address1>$address</Address1>
         <City>$city</City>
          <State>$state</State>
          <PostCode>$zip</PostCode>
          <CountryCode>$iso_country_code_numeric</CountryCode>
        </BillingAddress>
        <EmailAddress>$email</EmailAddress>
        <PhoneNumber>$phone</PhoneNumber>
        <CustomerIPAddress>$ipaddress</CustomerIPAddress>
      </CustomerDetails>
    </PaymentMessage>
  </CardDetailsTransaction>
</soap:Body>
</soap:Envelope>
EOX

	my $card = getcardtypeCardsave($pan, $username, $password);
	  
	   $::Session->{'CardType'} = $result{'CardType'} = $card->{'CardType'} if $card->{'CardType'};
	   $::Session->{'CardIssuer'} = $result{'CardIssuer'} = $card->{'Issuer'}->{'content'} if $card->{'Issuer'} =~ /HASH/;
	   $::Session->{'CardIssuer'} = $result{'CardIssuer'} = $card->{'Issuer'} if $card->{'Issuer'} !~ /HASH/;
	   $::Session->{'CardIssuerCode'} = $result{'CardIssuerCode'} = $card->{'Issuer'}->{'ISOCode'} if $card->{'Issuer'} =~ /HASH/;
	   $::Session->{'CardInfo'} = "$result{'CardType'}, $::Session->{'CardRef'}, $expshow" if $card->{'CardType'};
###::logDebug("Cardsave".__LINE__.": xmlOut=$xmlOut\ncardinfo=$::Session->{CardInfo}; issuer=$::Session->{CardIssuer}");	 
#::logDebug("Cardsave".__LINE__.": card-xmlback=".::uneval($card));

	my $msg = postCardsave($xmlOut);
	my $xml = new XML::Simple(Keyattr => 'CardDetailsTransactionResponse');
	my $data = $xml->XMLin("$msg");
#::logDebug("Cardsave".__LINE__.": xmlOut=$msg\n xmlback=".::uneval($data));
	   $data = $data->{'soap:Body'}->{'CardDetailsTransactionResponse'};

	   $result{'TxAuthNo'} = $data->{'TransactionOutputData'}->{'AuthCode'};
	   $result{'TDScheck'} = $data->{'TransactionOutputData'}->{'ThreeDSecureAuthenticationCheckResult'};
	   $result{'MD'}       = $data->{'TransactionOutputData'}->{'CrossReference'};
	   $result{'CardType'} = $data->{'TransactionOutputData'}->{'CardTypeData'}->{'CardType'};
###	   $result{'Issuer'}   = $data->{'TransactionOutputData'}->{'CardTypeData'}->{'Issuer'}->{'content'};
	   $result{'StatusCode'}  = $data->{'CardDetailsTransactionResult'}->{'StatusCode'};
	   $result{'AuthAttempt'} = $data->{'CardDetailsTransactionResult'}->{'AuthorisationAttempted'};
	   $result{'TDSmessage'}  = $data->{'CardDetailsTransactionResult'}->{'Message'};

	   $result{'CardRef'}  = $::Session->{'CardRef'} = $cardref;
	   $result{'CardInfo'} = $::Session->{'CardInfo'};

	  if ($data->{'CardDetailsTransactionResult'}->{'ErrorMessages'}->{'MessageDetail'} =~ /ARRAY/) {
		for my $i (0 .. 4) {
			#$::Session->{'errors'}{'Payment error'} =~ s/Passed variable: CardDetails\.//g;
			#$::Session->{'errors'}{'Payment error'} =~ s/Required variable: //g;
			#$::Session->{'errors'}{'Payment error'} =~ s/type //g;
			$::Session->{'errors'} .= "<p>$data->{'CardDetailsTransactionResult'}->{'ErrorMessages'}->{'MessageDetail'}[$i]{'Detail'}"; 
			$result{'MErrMsg'} .= $::Session->{'errors'};
				}
			}
	  else {
		    $::Session->{'errors'}{'Payment error'} = $data->{'CardDetailsTransactionResult'}->{'ErrorMessages'}->{'MessageDetail'}->{'Detail'};
		    if ($::Session->{'errors'}{'Payment error'} =~ /PaymentMessage\.CardDetails\.CardNumber/i) {
				$::Session->{'errors'}{'Payment error'} = 'Credit Card is missing';
			}
	  }

#::logDebug("Cardsave".__LINE__.": type=$result{CardType}; errors = $::Session->{'errors'}{'Payment error'}");

#::logDebug("Cardsave".__LINE__.": authcode=$result{TxAuthNo}, cardref=$result{CardRef}; cardinfo=$result{CardInfo}; xref-md=$result{MD}; stcode=$result{statuscode}; TDSattmp=$result{AuthAttempt}; TDSmsg=$result{TDSmessage}");

	 my $PaReq = $data->{'TransactionOutputData'}->{'ThreeDSecureOutputData'}->{'PaREQ'};
	 my $acsurl = $data->{'TransactionOutputData'}->{'ThreeDSecureOutputData'}->{'ACSURL'};
#::logDebug("Cardsave".__LINE__.": tds: PaReq=$PaReq\nacsurl=$acsurl");   

#................................................................................................
# Now go off to the ACS
#
	  if (defined $acsurl) {
#::logDebug("Cardsave".__LINE__." started TDSpost to ACS $acsurl; on=$::Values->{mv_order_number};");

		$::Scratch->{'acsurl'}  = $acsurl;
		$::Scratch->{'pareq'}   = $PaReq;
		$::Scratch->{'termurl'} = $termurl;
		$::Scratch->{'md'}      = $result{'MD'};
		$::Session->{'payment_id'} = $order_id;
		$::Scratch->{'tdspause'} = '1';
		$::Scratch->{'mstatus'}  = 'pause';
		$::Scratch->{'tdspostdone'} = '';
		$result{'PaReq'} = $PaReq;
	    $result{'MStatus'} = 'pause';
#	    undef $::Session->{'errors'}; # remove 'die' msg from log_transaction
		undef $acsurl;

	$::Scratch->{'tdsreturned'} = $::Scratch->{'tdsbounced'} = '';
	
#::logDebug("Cardsave".__LINE__." termurl=$termurl; $::Session->{'order_id'}");
	my $tdsfinal = $Tag->area({ href => "$tdsfinalpage" });
	$Tag->tag({ op => 'header', body => <<EOB });
Status: 302 moved
Location: $tdsfinal
EOB

	   }
   }

#------------------------------------------------------------------------------------------------
# Returned from the ACS, now to post the 3DS results to Cardsave for authentication
#
	if ($cardsaverequest eq 'tdspost' and length $CGI->{'MD'}) {
#::logDebug("Cardsave".__LINE__." started $cardsaverequest; on=$::Values->{mv_order_number};");

		$result{'PaRes'} = $CGI->{'PaRes'} if $CGI->{'PaRes'};
        $result{'MD'}    = $CGI->{'MD'} if $CGI->{'MD'};
		$::Scratch->{'cardsaverequestdone'} = 'tdspost';
 		$::Values->{'cardsaverequest'} = '';
		$::Scratch->{'mstatus'} = '';
		undef $cardsaverequest;
		my $acspage = ::http()->{'entity'};

#::logDebug("Cardsave".__LINE__.": PaRes=$result{PaRes}\nMD=$result{MD}\n###acspage=$$acspage");

	my $xmlOut = $header;
	   $xmlOut .= <<EOX;
  <ThreeDSecureAuthentication xmlns="https://www.thepaymentgateway.net/">
    <ThreeDSecureMessage>
    <MerchantAuthentication MerchantID="$username" Password="$password" />
     <ThreeDSecureInputData CrossReference="$result{'MD'}">
        <PaRES>$result{'PaRes'}</PaRES>
      </ThreeDSecureInputData>
      <PassOutData>$passoutdata</PassOutData>
    </ThreeDSecureMessage>
  </ThreeDSecureAuthentication>
</soap:Body>
</soap:Envelope>
EOX

	my $msg  = postCardsave($xmlOut);
	my $xml  = new XML::Simple();
	my $data = $xml->XMLin("$msg");
#::logDebug("Cardsave".__LINE__.": xmlback=".::uneval($data));
       $data = $data->{'soap:Body'}->{'ThreeDSecureAuthenticationResponse'};

       if ($data->{'ThreeDSecureAuthenticationResult'}->{'ErrorMessages'}->{'MessageDetail'} =~ /ARRAY/) {
		for my $i (0 .. 4) {
			$::Session->{'errors'}{'Payment error'} .= "<p>$data->{'ThreeDSecureAuthenticationResult'}->{'ErrorMessages'}->{'MessageDetail'}[$i]{'Detail'}"; 
				}
			 }
	   else {
		    $::Session->{'errors'}{'Payment error'} = $data->{'ThreeDSecureAuthenticationResult'}->{'ErrorMessages'}->{'MessageDetail'}->{'Detail'};
	   }

	   if (length $::Session->{'errors'}{'Payment error'}) {
	 	 $result{'StatusCode'} = '5';
	   }
 
	   $result{'TxAuthNo'}    = $data->{'TransactionOutputData'}->{'AuthCode'};
	   $result{'CV2Result'}   = $data->{'TransactionOutputData'}->{'CV2CheckResult'};
	   $result{'AddressResult'} = $data->{'TransactionOutputData'}->{'AddressNumericCheckResult'};
	   $result{'PostCodeResult'} = $data->{'TransactionOutputData'}->{'PostCodeCheckResult'};
	   $result{'TDScheck'}   = $data->{'TransactionOutputData'}->{'ThreeDSecureAuthenticationCheckResult'};
	   $result{'MD'}    = $data->{'TransactionOutputData'}->{'CrossReference'};

	   $result{'StatusCode'}  = $data->{'ThreeDSecureAuthenticationResult'}->{'StatusCode'};
	   $result{'AuthAttempt'} = $data->{'ThreeDSecureAuthenticationResult'}->{'AuthorisationAttempted'};
	   $result{'TDSmessage'}  = $data->{'ThreeDSecureAuthenticationResult'}->{'Message'};

#::logDebug("Cardsave".__LINE__.": on=$::Values->{mv_order_number}; 3ds status=$result{StatusCode}; 3dsres=$result{TDScheck}; authattempt=$result{AuthAttempt}; resmsg=$result{TDSmessage}; authcode=$result{TxAuthNo}");		

# Now returned from Cardsave, so either complete or fail the 3DS transaction
       if ($result{'StatusCode'} == '0') {
		   $result{'SecureStatus'}  = 'OK';
		   $result{'MStatus'} = $result{'pop.status'} = 'success';
		   $result{'order-id'} ||= $::Session->{'order_id'};
		   $result{'TxType'} = uc($txtype);
		   $result{'Status'} = 'OK';
	       $result{'CardType'} = $::Session->{'CardType'};
		   $result{'CardInfo'} = $::Session->{'CardInfo'};
		   $result{'CardRef'}  = $::Session->{'CardRef'};
###		   $result{'CardIssuer'} = $::Session->{'CardIssuer'};
		   $result{'CardIssuerCode'} = $::Session->{'CardIssuerCode'};
		   $::Scratch->{'mstatus'} = 'success';
		   $::Scratch->{'order_id'} = $result{'order-id'};
		   $::Values->{'psp'} = charge_param('psp') || 'Cardsave';
   		   $::Session->{'payment_id'} = $result{'order-id'};
		   $::CGI::values{'mv_todo'} = 'submit';
		   $::Scratch->{'tdspause'} = '';
     	   $::Scratch->{'tds'} = 'yes' ;
		   $::Values->{'mv_payment'} = "Real-time card $::Session->{'CardInfo'}";
		   $::Values->{'mv_order_route'} ||= 'log copy_user main';
     	   $::Scratch->{'tdspostdone'} = 'yes' ;
     	   
					$Vend::Session->{'payment_result'} = \%result;

#::logDebug("Cardsave".__LINE__.": tdspostdone=$::Scratch->{'tdspostdone'}; SecureStatus=$result{'SecureStatus'} so now to run routes;");

					Vend::Dispatch::do_process();

					}

		else {

			   $result{'MStatus'} = $result{'pop.status'} = $::Scratch->{'mstatus'} = 'fail';
			   $result{'TDSerror'} = $result{'TDSmessage'};
			   $::Scratch->{'tds'} = '';
#::logDebug("Cardsave".__LINE__.": 3ds status=$result{StatusCode}; 3ds res=$result{TDScheck};  resmsg=$result{TDSmessage}");		
		 
		 }
    }

#------------------------------------------------------------------------------------------------
# Get the type and issuer of the card, for anti-fraud use
#
	if ($cardsaverequest eq 'getcardtype') {
#::logDebug("Cardsave".__LINE__." started $cardsaverequest for card $pan");
		getcardtypeCardsave($pan);
    }

#------------------------------------------------------------------------------------------------
# Is this useful? Rather try each listed gateway in turn if any fail
#
	if ($cardsaverequest eq 'getgatewayentrypoints') {
#::logDebug("Cardsave".__LINE__." started $cardsaverequest");

	my $xmlOut = $header;
	   $xmlOut .= <<EOX;
  <GetGatewayEntryPoints xmlns="https://www.thepaymentgateway.net/">
    <GetGatewayEntryPointsMessage>
      <MerchantAuthentication MerchantID="$username" Password="$password" />
    </GetGatewayEntryPointsMessage>
  </GetGatewayEntryPoints>
</soap:Body>
</soap:Envelope>
EOX

	my $msg = postCardsave($xmlOut);
	my $xml = new XML::Simple();
	my $data = $xml->XMLin("$msg");
#::logDebug("Cardsave".__LINE__.": xmlback=".::uneval($data));
    }

#------------------------------------------------------------------------------------------------
# Use the crossreference (MD) for repeat billing and refunds, without needing the card number
#
	if ($cardsaverequest eq 'crossreferencepost') {
#::logDebug("Cardsave".__LINE__." started $cardsaverequest");

	my $crossreference = $::Values->{'crossreference'};
	my $order_id  = charge_param('order_id') || $Tag->time({ body => "%Y%m%d%H%M%S" }); 
	   $order_id .=   "-" . $Tag->time({ body => "%H%M%S" }) if charge_param('order_id');
	   $order_id .=  $::Session->{id};
	   $::Session->{'order_id'} = $::Values->{'mv_transaction_id'} = $order_id;
	my $new_transaction = $::Values->{'new_transaction'} || 'FALSE';
#::logDebug("Cardsave".__LINE__.": sessoid=$::Session->{'order_id'}; void=$::Values->{'order_id'}");
	my $xmlOut = $header;
	   $xmlOut .= <<EOX;
 <CrossReferenceTransaction xmlns="https://www.thepaymentgateway.net/">
    <PaymentMessage>
     <MerchantAuthentication MerchantID="$username" Password="$password" />
      <TransactionDetails Amount="$amount" CurrencyCode="$iso_currency_code_numeric">
        <MessageDetails TransactionType="$txtype" NewTransaction="$new_transaction" CrossReference="$crossreference" />
        <OrderID>$order_id</OrderID>
        <OrderDescription>$orderdescription</OrderDescription>
	     <TransactionControl>
		  <EchoCardType>TRUE</EchoCardType>
		  <EchoAVSCheckResult>TRUE</EchoAVSCheckResult>
		  <EchoCV2CheckResult>TRUE</EchoCV2CheckResult>
		  <EchoAmountReceived>TRUE</EchoAmountReceived>
		  <DuplicateDelay>60</DuplicateDelay>
		  <AVSOverridePolicy>$avsoverridepolicy</AVSOverridePolicy>
		  <ThreeDSecureOverridePolicy>FALSE</ThreeDSecureOverridePolicy>
	     </TransactionControl>
      </TransactionDetails>
      <PassOutData>$passoutdata</PassOutData>
    </PaymentMessage>
  </CrossReferenceTransaction>
</soap:Body>
</soap:Envelope>
EOX
#::logDebug("Cardsave".__LINE__.": xmlout=$xmlOut");
	my $msg = postCardsave($xmlOut);
	my $xml = new XML::Simple();
	my $data = $xml->XMLin("$msg");
#::logDebug("Cardsave".__LINE__.": xmlback=".::uneval($data));
	   $data = $data->{'soap:Body'}->{'CrossReferenceTransactionResponse'};
	   $result{'StatusCode'}  = $data->{'CrossReferenceTransactionResult'}->{'StatusCode'};
	   $result{'AuthAttempt'} = $data->{'CrossReferenceTransactionResult'}->{'AuthorisationAttempted'};
	   $result{'TDSmessage'}  = $data->{'CrossReferenceTransactionResult'}->{'Message'};
	   $result{'MD'}          = $data->{'TransactionOutputData'}->{'CrossReference'};
#::logDebug("Cardsave".__LINE__.": xmlback=".::uneval($data));

    }
#-------------------------------------------------------------------------------------------------
# Now to complete things

#::logDebug("Cardsave".__LINE__.": on=$::Values->{mv_order_number}; MStatus=$result{MStatus}; SecureStatus=$result{'SecureStatus'}; TDSmsg=$result{'TDSmessage'}");
#::logDebug("Cardsave".__LINE__.": result=".::uneval(\%result));
	my $cardsavedate = $Tag->time({ body => "%A %d %B %Y, %k:%M:%S, %Z" });
	my $amountshow =  $amount/'100';
#::logDebug("Cardsave".__LINE__.": statuscode=$result{StatusCode}; req=$cardsaverequest");
# unless ($result{'SecureStatus'}) {
  if ($result{'StatusCode'} == '0') {
         $result{'MStatus'} = $result{'pop.status'} = $::Scratch->{'mstatus'} = 'success';
         $result{'order-id'} ||= $::Session->{'order_id'};
		 $::Values->{'mv_payment'} = "Real-time card $::Session->{'CardInfo'}";
#::logDebug("Cardsave".__LINE__.": mstatus=$result{'MStatus'}; orderid=$result{'order-id'}; $::Session->{'order_id'}"); 
		if (charge_param('mail_txn_approved') == '1') {
		$::Tag->email({ to => $mailto, from => $mailto, reply => $mailto,
						subject => "Cardsave txn approved",
						body => "At $cardsavedate you received payment from $cardholder of $currency$amountshow\n\n" });
					  }
			  }
   elsif ($result{'StatusCode'} != '0') {
         $result{'MStatus'} = $result{'pop.status'} = $::Scratch->{'mstatus'} = 'fail';
         $result{'order-id'} = $result{'pop.order-id'} = '';
         $result{'MErrMsg'} = charge_param('main3DSerror') || "Payment error: <br>"; # if $result{'TDSmessage'} eq 'FAILED';
         $result{'MErrMsg'} .= $result{'TDSmessage'} if $result{'TDSmessage'};
		 $result{'MErrMsg'} .= "$::Session->{'errors'}{'Payment error'}<br>";
		 $result{'MErrMsg'} .= " Authentication failed<br>" if $result{'TDScheck'}  eq 'FAILED';
		 $result{'MErrMsg'} .= " Billing Address \"$::Values->{address1}\" failed to match at your bank<br>" if ($result{'AddressResult'} eq 'FAILED' && charge_param('avsoverridepolicy') !~ /^P/i);
		 $result{'MErrMsg'} .= " Billing PostalCode \"$::Values->{zip}\" failed to match at your bank<br>" if ($result{'PostCodeResult'} eq 'FAILED' && charge_param('avsoverridepolicy') !~ /^A/i);
		 $result{'MErrMsg'} .= " Card Security Code match failed<br>" if ($result{'CV2Result'} eq 'FAILED' && charge_param('cv2ovreridepolicy') !~ /^P/i);
		 $::Session->{'errors'}{'Payment error'} = $result{'MErrMsg'};
#::logDebug("Cardsave".__LINE__.": on=$::Values->{mv_order_number}; mstatus=$result{'MStatus'}; MErrMsg=$result{'MErrMsg'}"); 
           }
  #    }

	   $::Session->{'errors'}{'Payment error'} .= "$result{'TDSmessage'}" if ($result{'StatusCode'} == '30');
# Now optionally email a message on certain failures, eg those that might indicate attempted fraud
	  my $ierror = lc($result{'TDSmessage'});

	  if (($ierror =~ /avs|declined|variable/i) and (charge_param('mail_txn_declined') == '1')) {
		   $::Tag->email({ to => "$mailto", from => "$mailto",
					subject => "Cardsave payment error",
					body => "\nCardholder: $cardholder
Card info: $::Session->{'CardInfo'}
Card issuer: $::Session->{'CardIssuer'}
Address: $::Values->{address1}, $::Values->{address2}
City, Postcode:  $::Values->{city}, $::Values->{zip}
Country: $::Values->{country}
OrderID: $::Session->{'order_id'}
AddressResult: $result{AddressResult}
PostCodeResult: $result{PostCodeResult}
CV2Result: $result{CV2Result}
SecureStatus: $result{SecureStatus}
AuthAttempt: $result{'AuthAttempt'}
TDSmessage: $result{'TDSmessage'}
MD (crossreference): $result{MD}
IP address: $ipaddress
Date of failure: $cardsavedate
Displayed errors: $::Session->{'errors'}{'Payment error'}
Logged Error: $result{'TDSmessage'}\n"
				 });
#::logDebug("Cardsave".__LINE__.": txn error of \"$result{TDSmessage}\" emailed to $mailto"); 
	}
	
#::logDebug("Cardsave".__LINE__." result:" .::uneval(\%result));

		return (%result);

}

#
#--------------------------------------------------------------------------------------------------
# End of main routine
#--------------------------------------------------------------------------------------------------
#

sub postCardsave {
	 my $self = shift;
	 my $ua = LWP::UserAgent->new;
	    $ua->timeout(30);
	 my $gw = $::Session->{'CardsaveHost'} || $host3;
#	 my $gw = $host4; # TESTING - this does not exist
	 my $req = HTTP::Request->new('POST' => $gw);
		$req->content_type('text/xml');
		$req->content_length( length($self) );
		$req->content($self);
	 my $res = $ua->request($req);
	 my $respcode = $res->status_line;
#::logDebug("Cardsave".__LINE__.": default gw=$gw; session gw=$::Session->{'CardsaveHost'}");

	if ($res->is_success && $res->content){
		$::Session->{'CardsaveHost'} = $gw;
#::logDebug("Cardsave".__LINE__.": session gw=$gw");
		return ($res->content());
			  }
	 else  { 
        $req->uri( $host3 );
        $res = $ua->request($req);
#::logDebug("Cardsave".__LINE__.": gw test 1 $host3");
          if ( $res->is_success && $res->content ) {
			  $::Session->{'CardsaveHost'} = $host3;
#::logDebug("Cardsave".__LINE__.": success gw=$host3");
			  return $res->content();
				}
          else { 
			  $req->uri( $host2 );
			  $res = $ua->request($req);
#::logDebug("Cardsave".__LINE__.":  gw test 2 $host2");
				if ( $res->is_success && $res->content ) {
#::logDebug("Cardsave".__LINE__.": success gw=$host2");
				   $::Session->{'CardsaveHost'} = $host2;
				   return $res->content();
					   }
				else { 
			  $req->uri( $host1 );
			  $res = $ua->request($req);
#::logDebug("Cardsave".__LINE__.": gw test 3 $host1");
				if ( $res->is_success && $res->content ) {
#::logDebug("Cardsave".__LINE__.": success gw=$host1");
				   $::Session->{'CardsaveHost'} = $host1;
				   return $res->content();
					  }
				else {
#::logDebug("Cardsave".__LINE__.": CARDSAVE RESPONSE IS FAILURE $respcode");
					die ::errmsg("No response from the Cardsave payment gateway, please consider using Paypal instead or try again a little later. Our apologies. ");
					}
				} 
          } 
     }
}

sub getcardtypeCardsave {

	my ($pan, $username, $password) = @_;
	my $xmlOut = <<EOX;
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema"
               xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Body>
<GetCardType xmlns="https://www.thepaymentgateway.net/">
    <GetCardTypeMessage>
      <MerchantAuthentication MerchantID="$username" Password="$password" />
      <CardNumber>$pan</CardNumber>
    </GetCardTypeMessage>
  </GetCardType>
</soap:Body>
</soap:Envelope>
EOX
#::logDebug("\n===============================Cardsave".__LINE__.": cardtype xmlout=$xmlOut");
my $msg = postCardsave($xmlOut);
	my $xml = new XML::Simple();
	my $data = $xml->XMLin("$msg");
#::logDebug("Cardsave".__LINE__.": cardref=$::Session->{CardRef}");
#::logDebug("Cardsave".__LINE__.": cardref=$::Session->{CardRef} : uneval cardtype=".::uneval($data));
	   $data = $data->{'soap:Body'}->{'GetCardTypeResponse'}->{'GetCardTypeOutputData'}->{'CardTypeData'};
#::logDebug("Cardsave".__LINE__.": card type data=$data\n===================================================\n");
		return($data);

}

package Vend::Payment::Cardsave;

1;
