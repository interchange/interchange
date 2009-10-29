# Vend::Payment::SagePay - Interchange Sagepay support
#
# SagePay.pm, v 0.8.7, May 2009
#
# Copyright (C) 2009 Zolotek Resources Ltd. All rights reserved.
#
# Author: Lyn St George <info@zolotek.net, http://www.zolotek.net>
# Based on original code by Mike Heins <mheins@perusion.com> and others.
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public Licence as published by
# the Free Software Foundation; either version 2 of the Licence, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public Licence for more details.
#
# You should have received a copy of the GNU General Public
# Licence along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.



package Vend::Payment::SagePay;

=head1 Interchange Sagepay Support

Vend::Payment::SagePay $Revision: 0.8.7 $

http://kiwi.zolotek.net is the home page with the latest version.

=head1 This package is for the 'SagePay Direct' payment system.

Note that their 'Direct' system is the only one which leaves the customer on
your own site and takes payment in real time. Their other systems, eg Terminal
or Server, do not require this module.



=head1 Quick Start Summary

1 Place this module in <IC_root>/lib/Vend/Payment/SagePay.pm

2 Call it in interchange.cfg with:
    Require module Vend::Payment::SagePay

3 Add into variable.txt (tab separated):
    MV_PAYMENT_MODE   sagepay
  Add a new route into catalog.cfg (options for the last entry in parentheses):
    Route sagepay id YourSagePayID
    Route sagepay host live.sagepay.com (test.sagepay.com)
    Route sagepay currency GBP (USD, EUR, others, defaults to GBP)
    Route sagepay txtype PAYMENT (AUTHENTICATE, DEFERRED)
    Route sagepay available yes (no, empty)
    Route sagepay logzero yes (no, empty)
    Route sagepay logorder yes (no, empty)
    Route sagepay logsagepay yes (no, empty)
    Route sagepay applyavscv2 '0': if enabled then check, and if rules apply use.
                    '1': force checks even if not enabled; if rules apply use.
                    '2': force NO checks even if enabled on account.
                    '3': force checks even if not enabled; do NOT apply rules.
    Route sagepay giftaidpayment 0 (1 to donate tax to Gift Aid)

4 Create a new locale setting for en_GB as noted in "item currency" below, and copy the
public space interchange/en_US/ directory to a new interchange/en_GB/ one. Ensure that any
other locales you might use have a correctly named directory as well. Ensure that this locale
is found in your version of locale.txt (and set up GB as opposed to US language strings to taste).

5 Create entry boxes on your checkout page for: 'mv_credit_card_issue_number', 'mv_credit_card_start_month',
'mv_credit_card_start_year', 'mv_credit_card_type' and  'mv_credit_card_cvv2'.

6 The new fields in API 2.23 are: BillingAddress, BillingPostCode, DeliveryAddress, DeliveryPostCode,
BillingFirstnames, BillingSurname, DeliveryFirstnames, DeliverySurname, ContactNumber,ContactFax,CustomerEmail.
CustomerName has been removed. Billing and Delivery State must be sent if the destination country is the US, otherwise
they are not required. State must be only 2 letters if sent. Other fields may default to a space if there
is no proper value to send, though this may conflict with your AVS checking rules. SagePay currently 
accept a space as of time of writing - if they change this without changing the API version then send
either a series of '0' or '-' characters to stop their error messages. 

7. Add a page in pages/ord/, tdsfinal.html, being a minimal page with only the header and side bar,
and in the middle of the page put:
[if scratch acsurl]
	  <tr>
		<td align=center height=600 valign=middle colspan=2>
		  <iframe src="__CGI_URL__/ord/tdsauth.html" frameborder=0 width=600 height=600></iframe>
		</td>
	  </tr>
[/if]

Add a page in pages/ord/, tdsauth.html, consisting of this:
<body onload="document.form.submit();">
<FORM name="form" action="[scratchd acsurl]" method="POST" />
<input type="hidden" name="PaReq" value="[scratch pareq]" />
<input type="hidden" name="TermUrl" value="[scratch termurl]" />
<input type="hidden" name="MD" value="[scratch md]" />
</form>
</body>
along with whatever <noscript> equivalent you want. This will retrieve the bank's page within the iframe.

Add a page in pages/ord/, tdsreturn.html, consisting of this:
	[charge route="sagepay" sagepayrequest="3dsreturn"]
	<p>
	   <blockquote>
        <font color="__CONTRAST__">
                [error all=1 keep=1 show_error=1 show_label=1 joiner="<br>"]
        </font>
       </blockquote>

The iframe in 'tdsfinal' will be populated with the contents of 'tdsauth', and the javascript will
automatically display the bank's authentication page. When the customer clicks 'Submit' at the bank's
page, the iframe contents will be replaced with the 'tdsreturn' page, which will complete the route 
and display the receipt inside the iframe. If the customer clicks 'cancel' at the bank, then this 
'tdsreturn' page will stay put and display whatever message you have put there along with the error message. 
The value of [scratch tds] is set true for a 3DSecure transaction only, so can be used for messages
etc on the receipt page. 

8. When running a card through 3DSecure, the route is run twice: firstly to Sagepay who check whether or
not the card is part of 3DSecure - if it is they send the customer to the bank's authentication page
and upon returning from that the route must be run a second time to send the authentication results to
Sagepay. The second run is initiated from the 'ord/tdsreturn' page, not from etc/log_transaction as it normally
would be. To handle this change to the normal system flow you need to alter log_transaction to make the 
call to the payment module conditional,ie, wrap the following code around the "[charge route...]" call 
found in ln 172 (or nearby):
	[if scratchd mstatus eq success]
	[tmp name="charge_succeed"][scratch order_id][/tmp]
	[else]
	[tmp name="charge_succeed"][charge route="[var MV_PAYMENT_MODE]" amount="[scratch tmp_remaining]" order_id="[value mv_transaction_id]"][/tmp]
	[/else]
	[/if]
If the first call to Sagepay returns a request to send the customer to the 3DSecure server, then IC will 
write a payment route error to the error log prior to sending the customer there. This error stops the
route completing and lets the 3DSecure process proceed as it should. This error is not raised if the card
is not part of 3DSecure, and instead the route completes as it normally would. 

Also add this line just after '&final = yes' near the end of the credit_card section of etc/profiles.order:
	&set=mv_payment_route sagepay

9. Add these new fields into log_transaction, to record the values returned from Sagepay (these will be
key in identifying transactions and problems in any dispute with them):

mv_credit_card_type: [calc]$Session->{payment_result}{CardType}[/calc]
mv_credit_card_issue_number: [value mv_credit_card_issue_number]
txtype:  [calc]$Session->{payment_result}{TxType};[/calc]
vpstxid: [calc]$Session->{payment_result}{VPSTxID};[/calc]
txauthno: [calc]$Session->{payment_result}{TxAuthNo};[/calc]
securitykey: [calc]$Session->{payment_result}{SecurityKey};[/calc]
vendortxcode:  [calc]$Session->{payment_result}{VendorTxCode};[/calc]
avscv2: [calc]$Session->{payment_result}{AVSCV2};[/calc]
addressresult:[calc]$Session->{payment_result}{AddressResult};[/calc]
postcoderesult: [calc]$Session->{payment_result}{PostCodeResult};[/calc]
cv2result: [calc]$Session->{payment_result}{CV2Result};[/calc]
securestatus:[calc]$Session->{payment_result}{SecureStatus};[/calc]
pares: [calc]$Session->{payment_result}{PaRes};[/calc]
md: [calc]$Session->{payment_result}{MD};[/calc]
cavv: [calc]$Session->{payment_result}{CAVV};[/calc]
and add these into your MySQL or Postgres transactions table, as type varchar(128) except for 'pares'
which should be type 'text'.

Note that there is no 'TxAuthNo' returned for a successful AUTHENTICATE.

=head1 PREREQUISITES

  Net::SSLeay
    or
  LWP::UserAgent and Crypt::SSLeay

  wget - a recent version built with SSL and supporting the 'connect' timeout function.


=head1 DESCRIPTION

The Vend::Payment::SagePay module implements the SagePay() routine for use with
Interchange. It is _not_ compatible on a call level with the other Interchange
payment modules - SagePay does things rather differently. 

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::SagePay

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).


=head1 The active settings.

The module uses several of the standard settings from the Interchange payment routes.
Any such setting, as a general rule, is obtained first from the tag/call options on
a page, then from an Interchange order Route named for the mode in catalog.cfg,
then a default global payment variable in products/variable.txt, and finally in
some cases a default will be hard-coded into the module.

=over

=item Mode

The mode can be named anything, but the C<gateway> parameter must be set
to C<sagepay>. To make it the default payment gateway for all credit card
transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  sagepay
or in variable.txt:
    MV_PAYMENT_MODE sagepay (tab separated)

if you want this to cooperate with other payment systems, eg PaypalExpress, then see the documentation
that comes with that system - it should be fully explained there.


=item id

Your SagePay vendor ID, supplied by SagePay when you sign up. Various ways to state this:
in variable.txt:
    MV_PAYMENT_ID   YourSagePayID Payment
or in catalog.cfg either of:
    Route sagepay id YourSagePayID
    Variable MV_PAYMENT_ID      YourSagePayID
or on the page
    [charge route=sagepay id=YourSagePayID]


=item txtype

The transaction type is one of: PAYMENT, AUTHENTICATE, DEFERRED for an initial purchase
through the catalogue, and then can be one of: AUTHORISE, REFUND, RELEASE, VOID, ABORT for payment
operations through the virtual terminal.

The transaction type is taken firstly from a dynamic variable in the page, meant
primarily for use with the 'virtual payment terminal', viz: 'transtype' in a select box
though this could usefully be taken from a possible entry in the products database
if you have different products to be sold on different terms; then falling back to
a 'Route txtype PAYMENT' entry in catalog.cfg; then falling back to a global
variable in variable.txt, eg 'MV_PAYMENT_TXTYPE PAYMENT Payment'; and finally
defaulting to 'PAYMENT' hard-coded into the module. This variable is returned to
the module and logged using the value returned from SagePay, rather than a value from
the page which possibly may not exist.


=item available

If 'yes', then the module will check that the gateway is responding before sending the transaction.
If it fails to respond within 9 seconds, then the module will go 'off line' and log the transaction
as though this module had not been called. It will also log the txtype as 'OFFLINE' so that you
know you have to put the transaction through manually later (you will need to capture the card
number to do this). The point of this is that your customer has the transaction done and dusted,
rather than being told to 'try again later' and leaving for ever. If not explicitly 'yes',
defaults to 'no'. NB: if you set this to 'yes', then add into the etc/report that is sent to you:
Txtype = [calc]$Session->{payment_result}{TxType};[/calc]. Note that you need to have
a recent version of wget which supports '--connect-timeout' to run this check. Note also that,
as this transaction has not been logged anywhere on the SagePay server, you cannot use their
terminal to process it. You must use a virtual terminal which includes a function for this purpose,
and updates the existing order number with the new payment information returned from SagePay. Note
further that if you have SagePay set up to require the CV2 value, then virtual terminal should disable
CV2 checking at run-time by default for such a transaction (logging the CV2 value breaks Visa/MC
rules and so it can't be legally available for this process).


=item logzero

If 'yes', then the module will log a transaction even if the amount sent is zero (which the
gateway would normally reject). The point of this is to allow a zero amount in the middle of a
subscription billing series for audit purposes. If not explicitly 'yes', defaults to 'no'.
Note: this is only useful if you are using an invoicing system or the Payment Terminal, both of which
by-pass the normal IC processes. IC will allow an item to be processed at zero total price but simply
bypasses the gateway when doing so.


=item logempty
If 'yes, then if the response from SagePay is read as empty (ie, zero bytes) then the module will use the
VendorTxID to check on the Sagepay txstatus page to see if that transaction has been logged. If it has then
the result found on that page will be used to push the result to either success or failure and log accordingly.
There are two markers set to warn of this:
$Session->{payment_result}{TxType} will be NULL,
$Session->{payment_result}{StatusDetail} will be: 'UNKNOWN status - check with SagePay before dispatching goods'
and you should include these into the report emailed to you. It will also call a logorder Usertag to log
a backup of the order: if you don't already have this then get it from ftp.zolotek.net/mv/logorder.tag

If the result is not found on that txstatus page then the result is forced to 'failure' and the transaction 
shown as failed to the customer. 


=item card_type

SagePay requires that the card type be sent. Valid types are: VISA, MC, AMEX, DELTA, SOLO, MAESTRO, UKE,
JCB, DINERS (UKE is Visa Electron issued in the UK).

You may display a select box on the checkout page like so:

              <select name=mv_credit_card_type>
          [loop
                  option=mv_credit_card_type
                  acclist=1
                  list=|
VISA=Visa,
MC=MasterCard,
SOLO=Solo,
DELTA=Delta,
MAESTRO=Maestro,
AMEX=Amex,
UKE=Electron,
JCB=JCB,
DINERS=Diners|]
          <option value="[loop-code]"> [loop-param label]
          [/loop]
          </select>


=item currency

SagePay requires that a currency code be sent, using the 3 letter ISO currency code standard,
eg, GBP, EUR, USD. The value is taken firstly from either a page setting or a
possible value in the products database, viz 'iso_currency_code'; then falling back
to the locale setting - for this you need to add to locale.txt:

    code    en_GB   en_EUR  en_US
    iso_currency_code   GBP EUR USD

It then falls back to a 'Route sagepay currency EUR' type entry in catalog.cfg;
then falls back to a global variable (eg MV_PAYMENT_CURRENCY EUR Payment); and
finally defaults to GBP hard-coded into the module. This variable is returned to
the module and logged using the value returned from SagePay, rather than a value from
the page which possibly may not exist.


=item cvv2

This is sent to SagePay as mv_credit_card_cvv2. Put this on the checkout page:

    <b>CVV2: &nbsp; <input type=text name=mv_credit_card_cvv2 size=6></b>

but note that under Card rules you must not log this value anywhere.


=item issue_number

This is used for some debit cards, and taken from an input box on the checkout page:

    Card issue number: <input type=text name=mv_credit_card_issue_number value='' size=6>

=item mvccStartDate

This is used for some debit cards, and is taken from select boxes on the
checkout page in a similar style to those for the card expiry date. The labels to be
used are: 'mv_credit_card_start_month', 'mv_credit_card_start_year'. Eg:

		  <select name=mv_credit_card_start_year>
		  [loop option=start_date_year lr=1 list=`
		  my $year = $Tag->time( '', { format => '%Y' }, '%Y' );
		  my $out = '';
		  for ($year - 7 .. $year) {
				  /\d\d(\d\d)/;
				  $last_two = $1;
				  $out .= "$last_two\t$_\n";
		  }
		  return $out;
		  `]
		  <option value="[loop-code]"> [loop-pos 1]
		  [/loop]
		  </select>

Make the select box for the start month a copy of the existing one for the expiry month, but with
the label changed and the addition of 
= --select --, 
as the first entry. This intentionally returns nothing for that selection and prevents the StartDate being sent.


=item SagePay API v2.23 extra functions
ApplyAVSCV2 set to:
	0 = If AVS/CV2 enabled then check them.  If rules apply, use rules. (default)
	1 = Force AVS/CV2 checks even if not enabled for the account. If rules apply, use rules.
	2 = Force NO AVS/CV2 checks even if enabled on account.
	3 = Force AVS/CV2 checks even if not enabled for the account but DON'T apply any rules.
	You may pass this value from the page as 'applyavscv2' to override the payment route setting.
	They also have Paypal integrated into this version, but I have no interest in implementing Paypal 
	through Sagepay. There is a separate PaypalExpress module for that. 

ContactFax: optional
GiftAidPayment: set to -
	0 = This transaction is not a Gift Aid charitable donation(default)
	1 = This payment is a Gift Aid charitable donation and the customer has AGREED to donate the tax.
	You may pass this value from the page as 'giftaidpayment'
	
ClientIPAddress: will show in SagePay reports, and they will attempt to Geo-locate the IP.


=item AVSCV2
SagePay do not use your rulebase or return any checks for these when using 3ds and AUTHORISE. As this data
is essential for many business models you should use DEFERRED instead. While thought was given to
running a PAYMENT and VOID for £1 first, simply to get the AVSCV2 results, this cannot be done
with Maestro cards which legally must go through 3ds and so I have abandoned the idea. 


=item Encrypted email with card info

If you want to add the extra fields (issue no, start date) to the PGP message
emailed back to you, then set the following in catalog.cfg:

Variable<tab>MV_CREDIT_CARD_INFO_TEMPLATE Card type: {MV_CREDIT_CARD_TYPE}; Card no: {MV_CREDIT_CARD_NUMBER}; Expiry: {MV_CREDIT_CARD_EXP_MONTH}/{MV_CREDIT_CARD_EXP_YEAR}; Issue no: {MV_CREDIT_CARD_ISSUE_NUMBER}; StartDate: {MV_CREDIT_CARD_START_MONTH}/{MV_CREDIT_CARD_START_YEAR}


=item testing

The SagePay test site is test.sagepay.com, and their live site is
live.sagepay.com. Enable one of these in MV_PAYMENT_HOST in variable.txt
(*without* any leading https://) or as 'Route sagepay host test.sagepay.com' in
catalog.cfg. Be aware that the test site is not an exact replica of the live site, and errors there
can be misleading. In particular the "SecureStatus" returned from the test site is
liable to be 'NOTAUTHED' when the live site will return 'OK'.


=item methods

An AUTHENTICATE will check that the card is not stolen and contains sufficient funds.
SagePay will keep the details, so that you may settle against this a month or more
later. Against an AUTHENTICATE you may do an AUTHORISE (which settles the transaction).

A DEFERRED will place a shadow ('block') on the funds for seven days (or so, depending
on the acquiring bank). Against a DEFERRED you may do a RELEASE to settle the transaction.

A PAYMENT will take the funds immediately. Against a PAYMENT, you may do a
REFUND or REPEAT.

A REPEAT may be performed against an AUTHORISE or a PAYMENT. This will re-check and
take the funds in real time. You may then REPEAT a REPEAT, eg for regular
subscriptions. As you need to send the amount and currency with each REPEAT, you
may vary the amount of the REPEAT to suit a variation in subscription fees.

A RELEASE is performed to settle a DEFERRED. Payment of the originally specified
amount is guaranteed if the RELEASE is performed within the seven days for which
the card-holder's funds are 'blocked'.

A REFUND may be performed against a PAYMENT, RELEASE, or REPEAT. It may be for a
partial amount or the entire amount, and may be repeated with several partial
REFUNDs so long as the total does not exceed the original amount.

A DIRECTREFUND sends funds from your registered bank account to the nominated credit card.
This does not need to refer to any previous transaction codes, and is useful if you need to
make a refund but the customer's card has changed or the original purchase was not made by card.

=back

=head2 Troubleshooting

Try a sale with  any other test number given by SagePay, eg:
	Visa VISA 4929 0000 0000 6
    Mastercard  MC 5404 0000 0000 0001
    Delta DELTA 4462 0000 0000 0000 0003
    Visa Electron UK Debit  	UKE  	4917300000000008
    Solo SOLO 6334 9000 0000 0000 0005 issue no 1
    Switch (UK Maestro) MAESTRO 5641 8200 0000 0005 issue no 01.
    Maestro MAESTRO 300000000000000004
	AmericanExpress AMEX  	3742 0000 0000 004


You need these following values to ensure a positive response:
CV2: 123
Billing Address: 88
Billing PostCode: 412
and the password at their test server is 'password'.


If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::SagePay

=item *

Make sure either Net::SSLeay or Crypt::SSLeay and LWP::UserAgent are installed
and working. You can test to see whether your Perl thinks they are:

    perl -MNet::SSLeay -e 'print "It works\n"'
or
    perl -MLWP::UserAgent -MCrypt::SSLeay -e 'print "It works\n"'

If either one prints "It works." and returns to the prompt you should be OK
(presuming they are in working order otherwise).

=item *

Check the error logs, both catalogue and global. Make sure you set your payment
parameters properly. Try an order, then put this code in a page:

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

If you have a PGP/GPG failure when placing an order through your catalogue
then this may cause the module to be immediately re-run. As the first run would
have been successful, meaning that both the basket and the credit card information
would have been emptied, the second run will fail. The likely error message within
the catalogue will be:
"Can't figure out credit card expiration". Fixing PGP/GPG will fix this error.

If you get the same error message within the Virtual Terminal, then you haven't
set the order route as noted above.


=item *

If all else fails, Zolotek and other consultants are available to help
with integration for a fee.

=back


=head1 AUTHORS

Lyn St George <info@zolotek.net>, based on original code by Mike Heins
<mike@perusion.com> and others.

=head2 CREDITS
Hillary Corney (designersilversmiths.co.uk), Jamie Neil (versado.net),
Andy Mayer (andymayer.net) for testing and suggestions.



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
            require CGI;
            require Encode;
             import Encode qw(encode decode);
             import HTTP::Request::Common qw(POST);
            $selected = "LWP and Crypt::SSLeay";
        };

        $Vend::Payment::Have_LWP = 1 unless $@;
    }

    unless ($Vend::Payment::Have_Net_SSLeay or $Vend::Payment::Have_LWP) {
        die __PACKAGE__ . " requires Net::SSLeay or Crypt::SSLeay";
    }

::logGlobal("%s 0.8.8 payment module initialised, using %s", __PACKAGE__, $selected)
        unless $Vend::Quiet;

}

package Vend::Payment;
use strict; 

sub sagepay {
	
	my $sagepaystart = time;
	my $date = $Tag->time({ body => "%Y%m%d%H%M%S" });
	my $sagepaydate = $Tag->time({ body => "%A %d %B %Y, %k:%M:%S, %Z" });
	
	my ($vendor, $amount, $actual, $opt, $sagepayrequest, $page, $vendorTxCode, $pan, $cardType);
	
	# Amount sent to SagePay, in 2 decimal places with cruft removed.
	# Defaults to 'amount' from log_transaction or an invoicing system, falling back to IC input
	   $amount =  $::Values->{amount} || charge_param('amount') || Vend::Interpolate::total_cost();
	   $amount =~ s/^\D*//g;
	   $amount =~ s/\,//g;
	   $amount =  sprintf '%.2f', $amount;
	
	# Transaction type sent to SagePay.
	my $txtype      = $::Values->{transtype} || charge_param('txtype') || $::Variable->{MV_PAYMENT_TRANSACTION} ||'PAYMENT';
	my $vpsprotocol = '2.23';
	my $accountType = $::Values->{account_type} || charge_param('account_type') || 'E';
	my $payID       = $::Values->{inv_no} || $::Session->{mv_transaction_id} || $::Session->{id}.$amount;
	my $logorder    = charge_param('logorder') || 'no'; # Set to 'yes' or '1' to log basket plus data useful when arguing with SagePay over empty responses
	my $logsagepay  = charge_param('logsagepay') || 'no'; # Set to yes or 1 to log sagepay activity for debugging
	my $logzero     = charge_param('logzero')   || 'no';
	my $available   = $::Values->{available} || charge_param('available')  || 'no';
	my $description = "$::Values->{company} $::Values->{fname} $::Values->{lname}";
	   $description = substr($description,0,99);
	my $apply3ds    = $::Values->{apply3ds} ||  charge_param('apply3ds') || '0'; # '2' will turn 3ds off, '0' is default live variant
	my $applyAVSCV2 = $::Values->{applyavscv2} || charge_param('applyavscv2') || '0';
	my $termurl     = charge_param('returnurl') || "$::Variable->{SECURE_SERVER}$::Variable->{CGI_URL}/ord/tdsreturn";
	my $tdscallback = charge_param('tdscallback') || '/gateway/service/direct3dcallback.vsp';
	my $checkouturl = charge_param('checkouturl') || "$::Variable->{SECURE_SERVER}$::Variable->{CGI_URL}/ord/checkout";
	my $checkstatus = charge_param('check_status') || '1';
	my $checkstatusurl = charge_param('check_status_url') || '/TxStatus/TxStatus.asp';
	my $allowmaestro   = charge_param('allowmaestro'); # Allow Maestro card transactions to be logged offline - you will need a MOTO a/c to convert to online without 3DS.
#::logDebug("SP".__LINE__.": apply3ds=$apply3ds; avscv2=$applyAVSCV2; txtype=$txtype. $::Values->{transtype}, $tx");
		
		$::Scratch->{tds} = '';
		$::Scratch->{mstatus} = '';
		$::Values->{amount} = '';
		$::Values->{transtype} = '';
		$::Values->{inv_no} = '';
		$::Values->{apply3ds} = '';
		$::Values->{applyavsvc2} = '';
		$::Values->{account_type} = '';
		my $billingState;
		my $deliveryState;
	
	my %result;
	my %query;
	
	my (%actual) = map_actual();
		$actual  = \%actual;
		$opt     = {};
	
		$vendor   = $opt->{id} || charge_param('id') || $::Variable->{MV_PAYMENT_ID};
		$opt->{host} = charge_param('host') || $::Variable->{MV_PAYMENT_HOST} || 'live.sagepay.com';
		$sagepayrequest = $opt->{sagepayrequest} = charge_param('sagepayrequest') || 'post';
		$opt->{use_wget} = charge_param('use_wget') || '1';
		$opt->{port}   = '443';
#::logDebug("SP".__LINE__.": host=$opt->{host}; spreq=$sagepayrequest");
	
	if ($txtype =~ /DEFERRED|PAYMENT|AUTHENTICATE|DEFAUTH/i) {
		$opt->{script} = '/gateway/service/vspdirect-register.vsp';
				}
	elsif ($txtype =~ /RELEASE/i) {
		$opt->{script} = '/gateway/service/release.vsp';
				}
	elsif ($txtype =~ /DIRECTREFUND/i) {
		$opt->{script} = '/gateway/service/directrefund.vsp';
		}
	elsif ($txtype =~ /REFUND/i) {
		$opt->{script} = '/gateway/service/refund.vsp';
		}
	elsif ($txtype =~ /VOID/i) {
		$opt->{script} = '/gateway/service/void.vsp';
		}
	elsif ($txtype =~ /CANCEL/i) {
		$opt->{script} = '/gateway/service/cancel.vsp';
		}
	elsif ($txtype =~ /ABORT/i) {
		$opt->{script} = '/gateway/service/abort.vsp';
		}
	elsif ($txtype =~ /MANUAL/i) {
		$opt->{script} = '/gateway/service/manualpayment.vsp';
		}
	elsif ($txtype =~ /REPEAT|REPEATDEFERRED/i) {
		$opt->{script} = '/gateway/service/repeat.vsp';
		}
	elsif ($txtype =~ /AUTHORISE/i) {
		$opt->{script} = '/gateway/service/authorise.vsp';
		}
	
	
		my @override = qw/
							order_id
							mv_credit_card_exp_month
							mv_credit_card_exp_year
							mv_credit_card_start_month
							mv_credit_card_start_year
							mv_credit_card_issue_number
							mv_credit_card_number
						/;
		for(@override) {
			next unless defined $opt->{$_};
			$actual->{$_} = $opt->{$_};
		}
	
#::logDebug("SP".__LINE__." actual map result: " . ::uneval($actual));
	
	my $pan = $actual->{mv_credit_card_number} unless defined $pan;
 	   $pan =~ s/\D//g;
	   $actual->{mv_credit_card_exp_month}    =~ s/\D//g;
	   $actual->{mv_credit_card_exp_year}     =~ s/\D//g;
	   $actual->{mv_credit_card_exp_year}     =~ s/\d\d(\d\d)/$1/;
  	
	my $exp  = sprintf '%02d%02d',
			$actual->{mv_credit_card_exp_month}, $actual->{mv_credit_card_exp_year};
	
	my $expshow = $exp;
	   $expshow =~ s/(\d\d)(\d\d)/$1\/$2/;
	
	my $cardType  = $actual->{mv_credit_card_type} || $CGI->{mv_credit_card_type} || $::Values->{mv_credit_card_type} unless defined $cardType;
	   $cardType = 'MC' if ($cardType =~ /mastercard/i);
	
	my $mvccStartMonth = $actual->{mv_credit_card_start_month} || $::Values->{mv_credit_card_start_month} || $::Values->{start_date_month};
	   $mvccStartMonth =~ s/\D//g;
	
	my $mvccStartYear = $actual->{mv_credit_card_start_year} || $::Values->{mv_credit_card_start_year} || $::Values->{start_date_year};
	   $mvccStartYear =~ s/\D//g;
	   $mvccStartYear =~ s/\d\d(\d\d)/$1/;
	
	my $mvccStartDate;
		if ($mvccStartMonth == '') { $mvccStartDate = '';
			}
		else { $mvccStartDate = sprintf '%02d%02d', $mvccStartMonth, $mvccStartYear;
		}
	
	my $issue = $actual->{mv_credit_card_issue_number} || $::Values->{mv_credit_card_issue_number} ||  $::Values->{card_issue_number};
	   $issue =~ s/\D//g;
	
	my $cvv2  =  $actual->{mv_credit_card_cvv2} || $::Values->{cvv2};
	   $cvv2  =~ s/\D//g;
	
	# override the configured AVSCV2/3DS settings when using a terminal
	   $applyAVSCV2 = '2' unless ($txtype =~ /PAYMENT|DEFERRED|AUTHORISE/i);
	   $apply3ds = '2' unless ($txtype =~ /PAYMENT|DEFERRED|AUTHENTICATE/i);
	
# State must be only 2 letters, and is only required for the US. Other required fields default to a space to keep Sagepay happy.
# Filtering is now strict as Sagepay are making arbitrary changes to what they deem acceptable. 
	my $cardHolder         = "$actual->{b_fname} $actual->{b_lname}" || "$actual->{fname} $actual->{lname}";
	   $cardHolder         =~ s/[^a-zA-Z0-9,. ]//gi;
	my $billingSurname     = $actual->{b_lname} || $actual->{lname};
	   $billingSurname     =~ s/[^a-zA-Z0-9,. ]//gi;
	my $billingFirstnames  = $actual->{b_fname} || $actual->{fname};
	   $billingFirstnames  =~ s/[^a-zA-Z0-9,. ]//gi;
	my $billingCountry     = $actual->{b_country} || $actual->{country} || 'GB';
	   $billingCountry     = 'GB' if ($billingCountry =~ /UK/);
	my $billingAddress1    = $actual->{b_address} || $actual->{address} || ' ';
	   $billingAddress1    =~ s/\// /g;
	   $billingAddress1    =~ s/[^a-zA-Z0-9,. ]//gi; 
	my $billingAddress2    = $actual->{b_address2};
	   $billingAddress2    =~ s/[^a-zA-Z0-9,. ]//gi;
	my $billingPostCode    = $actual->{b_zip} || $actual->{zip} || ' ';
	   $billingPostCode    =~ s/[^a-zA-Z0-9 ]//gi;
	   $billingState       = $actual->{b_state} || $actual->{state} || '';
	my $billingCity        = $actual->{b_city} || $actual->{city} || ' ';
	   $billingCity       .= ", $billingState" unless $billingCountry =~ /US/i;
	   $billingCity        =~ s/[^a-zA-Z0-9,. ]//gi;
			undef $billingState unless  $billingCountry =~ /US/i;
	my $billingPhone	   = $actual->{b_phone} || $actual->{phone_day} || $actual->{phone_night};
	   $billingPhone       =~ s/[\(\)]/ /g;
	   $billingPhone       =~ s/[^0-9-+ ]//g;
	
	my $deliverySurname    = $actual->{lname};
	   $deliverySurname    =~ s/[^a-zA-Z0-9,. ]//gi;
	my $deliveryFirstnames = $actual->{fname};
	   $deliveryFirstnames =~ s/[^a-zA-Z0-9,. ]//gi;
	my $deliveryCountry    = $actual->{country} || 'GB';
	   $deliveryCountry    = 'GB' if ($deliveryCountry =~ /UK/);
	my $deliveryPostCode   = $actual->{zip} || ' ';
	   $deliveryPostCode   =~ s/[^a-zA-Z0-9 ]//gi;
	my $deliveryAddress1   = $actual->{address} || ' ';
	   $deliveryAddress1   =~ s/\// /gi;
	   $deliveryAddress1   =~ s/[^a-zA-Z0-9,. ]//gi;
	my $deliveryAddress2   = $actual->{address2};
	   $deliveryAddress2   =~ s/[^a-zA-Z0-9,. ]//gi;
	   $deliveryState      = $actual->{state} || '';
	my $deliveryCity       = $actual->{city} || ' ';
	   $deliveryCity      .= ", $deliveryState" unless $deliveryCountry =~ /US/i;
	   $deliveryCity       =~ s/[^a-zA-Z0-9,. ]//gi;
			undef $deliveryState unless $deliveryCountry =~ /US/i;
	my $deliveryPhone      = $actual->{phone_day} || $actual->{phone_night};
	   $deliveryPhone      =~ s/[\(\)]/ /g;
	   $deliveryPhone      =~ s/[^0-9-+ ]//g;
	
	my $customerEmail      = $actual->{email};
	   $customerEmail      =~ s/[^a-zA-Z0-9.\@\-_]//gi;
	my $contactFax         = $::Values->{fax} || '';
	   $contactFax         =~ s/[\(\)]/ /g;
	   $contactFax         =~ s/[^0-9-+ ]//gi;
	my $giftAidPayment     = $::Values->{giftaidpayment} || charge_param('giftaidpayment') || '0';
	my $authCode           = $::Values->{authcode} || '';
	my $clientIPAddress    = $CGI::remote_addr if $CGI::remote_addr;
			$::Values->{authcode} = '';
	
::logDebug("SP".__LINE__.": bCity=$billingCity; mvccType=$cardType; start=$mvccStartDate; issue=$issue;");
		
# ISO currency code sent to SagePay, from the page or fall back to config files.
	my $currency = $::Values->{iso_currency_code} || $::Values->{currency_code} || $Vend::Cfg->{Locale}{iso_currency_code} ||
						 charge_param('currency') || $::Variable->{MV_PAYMENT_CURRENCY} || 'GBP';
	
	my $psp_host = $opt->{host};
	my $convertoffline = charge_param('convertoffline');

#--- make the initial request to SagePay and get back the values for the ACS ---------------------------
if ($sagepayrequest eq 'post') {
   	$::Session->{sagepay}{CardRef}   = $pan;
   	$::Session->{sagepay}{CardRef}   =~ s/^(\d\d).*(\d\d\d\d)$/$1****$2/;
# vendorTxCode generated here in 'post', and retrieved from session later
 my $order_id  = $Tag->time({ body => "%Y%m%d%H%M%S" }); 
   	$order_id .= $::Session->{id};
	if ($txtype   =~ /RELEASE|VOID|ABORT|CANCEL/i) {
   		$::Session->{sagepay}{vendorTxCode} = $::Values->{OrigVendorTxCode}
       	}
	else {
   		$::Session->{sagepay}{vendorTxCode} = $order_id
	}

   %query   =    (
                    TxType                      => $txtype,
                    Vendor                      => $vendor,
                    AccountType                 => $accountType,
                    VPSProtocol                 => $vpsprotocol,
                    Apply3DSecure               => $apply3ds
                 );

	if ($txtype =~ /RELEASE/i) {
						$query{ReleaseAmount}       = $amount;
		}
	
	if ($txtype =~ /REFUND|REPEAT|AUTHORISE/) {
					$query{RelatedVPSTxID}      = $::Values->{RelatedVPSTxID};
					$query{RelatedVendorTxCode} = $::Values->{RelatedVendorTxCode};
					$query{RelatedSecurityKey}  = $::Values->{RelatedSecurityKey};
					$query{Description}         = $description;
					$query{Amount}              = $amount;
		}
	
	if ($txtype =~ /REFUND|REPEAT/) {
					$query{RelatedTxAuthNo}     = $::Values->{RelatedTxAuthNo};
					$query{Currency}            = $currency;
		}
	
	if ($txtype =~ /VOID|ABORT|CANCEL|RELEASE/i) {
					$query{VPSTxId}             = $::Values->{OrigVPSTxID};
					$query{SecurityKey}         = $::Values->{OrigSecurityKey};
		}
	
	if ($txtype =~ /VOID|ABORT|RELEASE/i) {
					$query{TxAuthNo}            = $::Values->{OrigTxAuthNo};
		}
	
	if ($txtype =~ /DIRECTREFUND|DEFERRED|PAYMENT|AUTHENTICATE|MANUAL/i) {
					$query{CardType}            = $cardType;
					$query{CardNumber}          = $pan;
					$query{CardHolder}          = $cardHolder;
					$query{Description}         = $description;
					$query{Amount}              = $amount;
					$query{Currency}            = $currency;
					$query{ExpiryDate}          = $exp;
		}
	
	if ($txtype =~ /PAYMENT|DEFERRED|AUTHENTICATE|MANUAL/i) {
					$query{BillingFirstNames}   = $billingFirstnames;
					$query{BillingSurname}      = $billingSurname;
					$query{BillingAddress1}     = $billingAddress1;
					$query{BillingAddress2}     = $billingAddress2 if $billingAddress2;
					$query{BillingCity}         = $billingCity;
					$query{BillingPostCode}     = $billingPostCode;
					$query{BillingState}        = $billingState if $billingState;
					$query{BillingCountry}      = $billingCountry;
					$query{BillingPhone}        = $billingPhone;
					$query{DeliveryFirstNames}  = $deliveryFirstnames;
					$query{DeliverySurname}     = $deliverySurname;
					$query{DeliveryAddress1}    = $deliveryAddress1;
					$query{DeliveryAddress2}    = $deliveryAddress2 if $deliveryAddress2;
					$query{DeliveryCity}        = $deliveryCity;
					$query{DeliveryPostCode}    = $deliveryPostCode;
					$query{DeliveryState}       = $deliveryState if $deliveryState;
					$query{DeliveryCountry}     = $deliveryCountry;
					$query{DeliveryPhone}       = $deliveryPhone;
					$query{ContactFax}          = $contactFax;
					$query{CustomerEmail}       = $customerEmail;
					$query{GiftAidPayment}      = $giftAidPayment;
					$query{ClientIPAddress}     = $clientIPAddress;
					$query{CV2}                 = $cvv2;
		}
	
	if ($txtype =~ /PAYMENT|DEFERRED|AUTHORISE/i) {
					$query{ApplyAVSCV2}         = $applyAVSCV2;
		}
	
					$query{AuthCode}            = $authCode if $authCode;
					$query{StartDate}           = $mvccStartDate if $mvccStartDate;
					$query{IssueNumber}         = $issue if $issue; 
	
	}

#--- return from ACS  ------------------------------------------------------------------------
 elsif ($sagepayrequest eq '3dsreturn') {
  		$::Values->{sagepayrequest} = '';
        $opt->{script} = $tdscallback;
        $result{PaRes} = $CGI->{'PaRes'};
        $result{MD}    = $CGI->{'MD'};

#::logDebug("SP".__LINE__.": New PaRes=$result{PaRes}\nMD=$result{MD}");
         
         %query = (
                    MD                => $result{MD},
                    PaRes             => $result{PaRes}
                  );
  
  }

#--- query status from admin panel ----------------------------------------------------
 elsif ($sagepayrequest eq 'querystatus') {
   my %statusquery = (
                      Vendor          => $vendor,
                       VendorTxCode    => charge_param('vendortxcode')
                     );
       
		$opt->{script} = $checkstatusurl;
		my $post       = post_data($opt, \%statusquery);
		my $response   = $post->{status_line};
		my $page       = $post->{result_page};

#::logDebug("SP".__LINE__.": query page = $page\n");
	
	for my $line (split /\r\n/, $page) {
		$result{Status}       = $1 if ($line =~ /^Status=(.*)/i); 
		$result{StatusDetail} = $1 if ($line =~ /StatusDetail=(.*)/i);
		$result{TxType}       = $1 if ($line =~ /TransactionType=(.*)/i);
		$result{Authorised}   = $1 if ($line =~ /Authorised=(.*)/i);
		$result{TxAuthCode}   = $1 if ($line =~ /VPSAuthCode of (\d+)/i);
		$result{VPSTxId}      = $1 if ($line =~ /VPSTxId=(.*)/i);
		$result{Amount}       = $1 if ($line =~ /Amount=(.*)/i);
		$result{Currency}     = $1 if ($line =~ /Currency=(.*)/i);
		$result{ReceivedDate} = $1 if ($line =~ /Received=(.*)/i);
		$result{BatchID}      = $1 if ($line =~ /BatchID=(.*)/i);
		$result{Settled}      = $1 if ($line =~ /Settled=(.*)/i);
		}
 }

#--- common stuff again --------------------------------------------------------------

my ($post, $response, @page);

# Test for gateway availability, and if not available optionally go off-line and complete
# transaction for manual processing later. Also go off-line if amount is zero, so as to log the
# transaction and email a receipt for audit purposes (useful mainly for subscription billing).

	my ($request, $in);

#::logDebug("SP".__LINE__.": available=$available, amount=$amount, order_route=$::Values->{mv_order_route}, logzero=$logzero");

if (($available =~ /y|1/i) and ($amount > 0) and ($::Values->{mv_order_route} !~ /ptipm_route/i)) {
 	my $CMD = '/usr/bin/wget -nv --spider -T9 -t1';
 		open (IN, "$CMD https://$psp_host 2>&1 |") || die "Could not open pipe to wget: $!\n";
   			$in = <IN>;
   			chop($in);
 		close(IN);
 
  		$in = 'test' if ($::CGI->{offline} eq 'yes'); # testing only, will force offline mode
   		if ($in =~ /^200 OK$/)  { 
   			$request = 'psp'; 
   			}
   		else { 
   			$request = 'offline'; 
   			}
   		if (($cardType =~ /MAESTRO|SWITCH/i) and ($allowmaestro != '1')) {
   			$request = 'psp'; # Maestro must go through 3D Secure unless merchant a/c type is set to MOTO in a terminal
   			}
    	}
	elsif (($::Values->{mv_order_route} =~ /ptipm_route/)  and ($amount > 0)) {
    	$request = 'psp';
    	}
	elsif (($available !~ /y|1/i) and ($amount > 0)) {
    	$request = 'psp';
    	}
	elsif (($amount == 0) and ($logzero =~ /y|1/i)) {
    	$request = 'log';
}
	 
	 $result{VendorTxCode} = $::Session->{sagepay}{vendorTxCode};
#::logDebug("SP".__LINE__.": in=$in; request=$request; cardtype=$cardType; vendorTxCode=$result{VendorTxCode}");

if ($request eq 'psp') {
# Run normal routine to SagePay

		$query{VendorTxCode} = $::Session->{sagepay}{vendorTxCode};

#::logDebug("SP".__LINE__.": now for keys in query");
  my @query;
    	foreach my $key (sort keys(%query)) {
    	::logDebug("Query to SagePay: \"$key=$query{$key}\""); # nicely readable version of the string sent
       	push @query, "$key=$query{$key}";
    	}
  
  my $string = join '&', @query; # replicates the string as actually sent: useful to quote this for debugging
#::logDebug("SP".__LINE__.": string to SagePay: $string");
		
		$post     = post_data($opt, \%query);
		$response = $post->{status_line};
		$page     = $post->{result_page};

::logDebug("SP".__LINE__.": response page:\n-------------------------\n$page \n---------------------------\nend of SagePay results page\n\n");
		
		$result{TxType}         = $txtype;
		$result{Currency}       = $currency;
		$result{CardRef}        = $::Session->{sagepay}{CardRef};
		$result{CardType}       = $cardType;
		$result{ExpAll}         = $exp;
		$result{amount}         = $amount;
		$result{request}        = $request;
		$result{IP}             = $clientIPAddress;
		$result{CardType}       = 'Electron' if ($cardType eq 'UKE');
		$result{CardInfo}       = "$result{CardType}, $result{CardRef}, $expshow";
	
# Find results off returned page
	for my $line (split /\r\n/, $page) {
		$result{VPSTxID}        = $1 if ($line =~ /VPSTxID=(.*)/i); 
	    $result{Status}         = $1 if ($line =~ /^Status=(.*)/i); 
 	    $result{StatusDetail}   = $1 if ($line =~ /StatusDetail=(.*)/i);
 	    $result{TxAuthNo}       = $1 if ($line =~ /TxAuthNo=(.*)/i);
		$result{SecurityKey}    = $1 if ($line =~ /SecurityKey=(.*)/i);
		$result{AVSCV2}         = $1 if ($line =~ /AVSCV2=(.*)/i);
		$result{VPSProtocol}    = $1 if ($line =~ /VPSProtocol=(.*)/i);
		$result{AddressResult}  = $1 if ($line =~ /AddressResult=(.*)/i);
		$result{PostCodeResult} = $1 if ($line =~ /PostCodeResult=(.*)/i);
		$result{CV2Result}      = $1 if ($line =~ /CV2Result=(.*)/i);
	
# and the 3DSecure results too
		$result{SecureStatus}   = $1 if ($line =~ /SecureStatus=(.*)/i);
		$result{MD}             = $1 if ($line =~ /MD=(.*)/i);
		$result{ACSURL}         = $1 if ($line =~ /ACSURL=(.*)/i);
		$result{PaReq}          = $1 if ($line =~ /PaReq=(.*)/i);
		$result{CAVV}           = $1 if ($line =~ /CAVV=(.*)/i);
		}
		
		$result{StatusDetail} =~ s/, vendor was .*/\./;
#::logDebug("SP".__LINE__.": cardRef=$result{CardRef}; txtype=$txtype; status=$result{Status}; detail=$result{StatusDetail}; securestatus=$result{SecureStatus}");

if ($txtype =~ /PAYMENT|DEFERRED|MANUAL|AUTHENTICATE/i) {
  
  if ($result{Status} =~ /3DAUTH/i) {
#::logDebug("SP".__LINE__.": started status=3DAUTH");
## Use scratch values below to populate form inside iframe. This gets the page from the bank and re-populates
## the iframe. This page is then replaced with the 'tdsreturn' page, which shows the error message
## if there is an error, otherwise it does not show at all but is silently replaced with the receipt.

		$::Scratch->{acsurl}  = $result{ACSURL};
		$::Scratch->{pareq}   = $result{PaReq};
		$::Scratch->{termurl} = $termurl;
		$::Scratch->{md}      = $result{MD};

	 my $sagepayfinal = $Tag->area({ href => "ord/tdsfinal" });
$Tag->tag({ op => 'header', body => <<EOB });
Status: 302 moved
Location: $sagepayfinal
EOB
      }

  elsif ($result{Status} =~ /OK|REGISTERED|AUTHENTICATED|ATTEMPTONLY/i) {
#::logDebug("SP".__LINE__.": reStatus=$result{Status}; securestatus=$result{SecureStatus}"); 
  	  if ($result{SecureStatus} =~ /NOTAUTHED/i) {
  		 $result{MStatus} = $result{'pop.status'} = 'failed';
   		 $::Scratch->{mstatus} = 'failed';
   		 $::Scratch->{tds} = '';
   		 		}
   	  else {
		 $result{MStatus} = $result{'pop.status'} = 'success' unless $convertoffline;
  		 $result{'order-id'} ||= $::Session->{sagepay}{vendorTxCode} unless $convertoffline;
  		 $result{'Terminal'} = 'success' if $convertoffline;
  		 $result{'TxType'} = uc($txtype);
 		 $result{'Status'} = 'OK';
   		 $::Scratch->{mstatus} = 'success';
   		 $::Scratch->{order_id} = $result{'order-id'};
   		 $::Values->{mv_payment} = "Real-time card $result{CardInfo}";
         $::Values->{psp} = charge_param('psp') || 'SagePay';
         $::CGI::values{mv_todo} = 'submit';
         	if ($result{SecureStatus} =~ /OK|ATTEMPTONLY/i) {
 	     		$::Scratch->{tds} = 'yes' ;
 	     		$Vend::Session->{payment_result} = \%result;

::logDebug("SP".__LINE__.": secureStatus=$result{SecureStatus} so now to run routes; result hash=".::uneval(\%result));

 	     		Vend::Dispatch::do_process();
 	     		}
 	     	}
#::logDebug("SP".__LINE__.": 3ds=$apply3ds; resStatus=$result{Status}; resSecureStatus=$result{SecureStatus}, mStatus= $result{MStatus}, orderid=$result{'order-id'}; tds=$::Scratch->{tds}\n");
		}

  elsif ($result{Status} =~ /NOTAUTHED/i) {
		$result{MStatus} = $result{'pop.status'} = 'failed';
		$::Scratch->{MStatus} = 'failed';
     	if ($result{StatusDetail} =~ /AVS/i) {
     		$::Session->{errors}{Address} =  "Data mismatch<br>Please ensure that your address matches the address on your credit-card statement, and that the card security number matches the code on the back of your card\n";
              }
     	else {
     		$::Session->{errors}{Payment} = "$result{StatusDetail} $result{Status}";
            }
#::logDebug("SP".__LINE__.": res status = $result{Status}; MSt: $result{MStatus} or $::Session->{payment_result}{MStatus}\n");
      	return;
      }

  elsif ($result{Status} =~ /\w+/) {
#::logDebug("SP".__LINE__.": resStatus (other) $result{Status}");
   		$result{MStatus} = $result{'pop.status'} = 'failed';
   		$::Scratch->{MStatus} = 'failed';
   		$result{MErrMsg} = $result{StatusDetail};
     	$::Session->{errors}{Payment} = "$result{Status} $result{StatusDetail} The address and/or security code entered do not match those on file.";
   		return;
 	  }
 
  elsif (!$result{Status}) {
#::logDebug("SP".__LINE__.": status=$result{Status}");
  # If the status response is read as empty, the customer will try to repeat the order. This next
  # Will try the 'check status' function first, but if the problem is that Sagepay are timing out 
  # then this may also timeout. If 'check status' is positive the transaction will be processed as 
  # though this glitch hadn't happened, otherwise it will be processed as a failure, thus preventing any 
  # attempt to repeat the order.
  		
		$logorder = '1';
		# Also log SagePay details for discussions with them
		$logsagepay = '1';
 	
 	my %statusquery = (
                      Vendor          => $vendor,
                      VendorTxCode    => $::Session->{sagepay}{vendorTxCode}
                      );
       $opt->{script} = $checkstatusurl;
    my $post     = post_data($opt, \%statusquery);
    my $response = $post->{status_line};
    my $page     = $post->{result_page};

#::logDebug("SP".__LINE__.": checkstatus=$checkstatus; page=$page");

		for my $line (split /\r\n/, $page) {
    		$result{VPSTxID}    = $1 if ($line =~ /VPSTxId=(.*)/i);
    		$result{Authorised} = $1 if ($line =~ /^Authorised=(.*)/i);
    		$result{TxAuthNo}   = $1 if ($line =~ /VPSAuthCode=(.*)/i);
   			 }
#::logDebug("SP".__LINE__.": checkstatus,result=$result{Authorised}; authcode=$result{VPSAuthCode}; vtxcode=$vendorTxCode"); 

       unless ($result{Authorised} =~ /YES/i) {
my $unknown = <<EOF;
ATTENTION: our payment processor has met an unexpected problem and we do not know if payment has
been taken or not. Please check back with $::Variable->{COMPANY} on $::Variable->{PHONE}, quoting this 
important reference point:
<p>
VendorTxCode:  $::Session->{sagepay}{vendorTxCode}
<p>
We apologise on behalf of our payment processor for the inconvenience
EOF
 
#::logDebug("SP".__LINE__.": $unknown\nresAuth=$result{Authorised}");
    	 $result{MStatus} = $result{'pop.status'};
     	 $result{'order-id'} ||= $opt->{order_id};
     	 $result{'TxType'} = 'NULL';
     	 $result{'Status'} = 'UNKNOWN status - check with SagePay before dispatching goods';
     	 $::Session->{errors}{SagePay} = $unknown;
     			}
       elsif($result{Authorised} =~ /YES/i) {
#::logDebug("SP".__LINE__.": SP response was empty, now TxStatus is $result{Authorised} so force to success");
         $result{MStatus} = $result{'pop.status'} = 'success';
  		 $result{'order-id'} ||= $::Session->{sagepay}{vendorTxCode};
 		 $result{'Status'} = 'OK';
		 $result{'MStatus'} = 'success';
		 $::Scratch->{mstatus} = 'success';
		 $result{'TxType'} = uc($txtype);
		 }
   }
}

# These next can only be done through a virtual terminal
	elsif($txtype =~ /RELEASE|REFUND|REPEAT|AUTHORISE|DIRECTREFUND|VOID|ABORT/i ) {
	if ($result{Status} =~ /OK/i) {
			$result{Terminal} = 'success';
			$result{'TxType'} = uc($txtype);
				}
	else {
			$result{MStatus} = $result{'pop.status'} = 'failed';
			$result{MErrMsg} = "$result{Status} $result{StatusDetail}";
				}
		}
	}

elsif ($request =~ /offline|log/i) {
# end of PSP request, now for either OFFLINE or LOG
  # force result to 'success' so that transaction completes
		 $vendorTxCode = $::Session->{sagepay}{vendorTxCode};
  		 $result{MStatus} = $result{'pop.status'} = 'success';
  		 $result{'order-id'} ||= $::Session->{sagepay}{vendorTxCode};
 		 $result{'Status'} = 'OK';
		 $result{CardRef}  = $::Session->{sagepay}{CardRef};
		 $result{CardType} = $cardType;
   		 $::Scratch->{mstatus} = 'success';
   		 $::Scratch->{order_id} = $result{'order-id'};
  		 $result{'TxType'} = uc($request);
   		 $::Values->{mv_payment} = "Processing card $result{CardInfo}";
         $CGI::values{mv_todo} = 'submit';

#::logDebug("SP".__LINE__.": request=$request; tds=$::Scratch->{tds}");
           
           }

     undef $request;
     $::Values->{request} = '';

	::logDebug("SP".__LINE__.":result=".::uneval(\%result));

# Now extra logging for backup order and/or log of events
	if ($logorder =~ /y|1/) {
#--- write the full basket and address to failsafe file 
	   $Tag->logorder('sagepay') or ::logError("SagePay: custom UserTag 'logorder.tag' not found"); # custom usertag to log full basket plus delivery details
		}
	
	if (($logorder =~ /y|1/) or ($logsagepay =~ /y|1/)) {
# Do we need this log??? Some have a keen interest in it ...
	my $sagepayend = time;
	my $sagepaytime = $sagepayend - $sagepaystart;
	   chomp($sagepaytime);
system("touch logs/sagepay.log");
open (OUT, ">>logs/sagepay.log");
printf OUT "
Date of transaction = $sagepaydate
Time to execute     = $sagepaytime seconds
CardHolder          = $cardHolder
Address             = $deliveryAddress1 $deliveryAddress2 $deliveryCity $deliveryState
PostCode            = $deliveryPostCode
Card reference      = $result{CardRef}
Card type           = $result{CardType}
Expiry              = $exp
Amount              = $amount
Currency            = $currency
VendorTxCode        = $::Session->{sagepay}{vendorTxCode}
SecurityKey         = $result{SecurityKey}
VPSTxID             = $result{VPSTxID}
TxAuthNo            = $result{TxAuthNo}
TxType              = $result{TxType}
Status              = $result{Status}
AddressResult       = $result{AddressResult}
PostCodeResult      = $result{PostCodeResult}
CV2Result           = $result{CV2Result}
SecureStatus        = $result{SecureStatus}
StatusDetail        = $result{StatusDetail}
IC result status    = $result{MStatus}
====================================================
";
close(OUT);

	}
		
	undef $apply3ds;
	$::Values->{apply3ds} = '';
    
    return (%result);
  
}

package Vend::Payment::SagePay;

1;

