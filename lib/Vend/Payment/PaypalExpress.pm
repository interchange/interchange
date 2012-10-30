# Vend::Payment::PaypalExpress - Interchange Paypal Express Payments module
#
# Copyright (C) 2011 Zolotek Resources Ltd
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
package Vend::Payment::PaypalExpress;

=head1 NAME

Vend::Payment::PaypalExpress - Interchange Paypal Express Payments Module

=head1 PREREQUISITES

    SOAP::Lite
    XML::Parser
    MIME::Base64
    URI
    libwww-perl
    Crypt::SSLeay
    IO::Socket::SSL   (version 0.97 until 0.99x is fixed for the "illegal seek" error, or a later one that works)

	Date::Calc - new for v1.1.0

Test for current installations with: perl -MSOAP::Lite -e 'print "It works\n"'

=head1 DESCRIPTION

The Vend::Payment::PaypalExpress module implements the paypalexpress() routine
for use with Interchange.

#=========================

=head1 SYNOPSIS

Quick start:

Place this module in <ic_root>/lib/Vend/Payment, and call it in <ic_root>/interchange.cfg with
Require module Vend::Payment::PaypalExpress. Ensure that your perl installation contains the modules
listed above and their pre-requisites.

Logon to your Paypal Business (not Personal) account and go to 'Profile' -> 'API access' ->
'Request API Credentials' -> 'Signature'. This will generate a user id, password and signature.

Add to catalog.cfg all marked 'required', optionally the others:
Route  paypalexpress id   xxx  (required_
Route  paypalexpress password xxx  (required)
Optionally for this updated version, you may prefix the three credentials above some unique
identifier, eg 'gbp', 'usd', 'sandbox' and the module will switch between them on the fly.
Useful if you have different Paypal a/cs in different currencies and want to choose the
a/c used based on the currency chosen by the customer.
Route  paypalexpress signature xxx (required: use the 3-token system, not the certificate system at Paypal)
Route  paypalexpress returnurl your_full_URL/paypalgetrequest (required)
Route  paypalexpress cancelurl your_full_URL/your_cancellation_page (required)
Route  paypalexpress host api-3t.sandbox.paypal.com  (for testing)
Route  paypalexpress host api-3t.paypal.com (required: live host, one of this or the above but not both)
Route  paypalexpress currency EUR|GBP|USD|CAD|AUD  (optional, defaults to USD)
Route  paypalexpress pagestyle (optional, set up at Paypal)
Route  paypalexpress paymentaction Sale (optional, defaults to 'Sale')
Route  paypalexpress headerimg 'secure URL' (optional, though must be served from a secure URL if used)

Optionally, you may set the return URL in the page as
<input type=hidden name=returnurl value=your_url>,
and similarly the cancelurl may be set in the page.

To have Paypal co-operate with your normal payment service provider, eg Authorizenet, do the following:

Leave the MV_PAYMENT_MODE variable in catalog.cfg and products/variable.txt set to your normal payment processor.

Add to etc/profiles.order:
__NAME__                       paypalexpress
__COMMON_ORDER_PROFILE__
&fatal = yes
email=required
email=email
&set=mv_payment PaypalExpress
&set=psp Paypal
&set=mv_payment_route paypalexpress
&final = yes
&setcheck = payment_method paypalexpress
__END__
or, if you want to use Paypal as a 'Buy now' button without taking any customer details, then omit the
__COMMON_ORDER_PROFILE__ and the two 'email=...' lines above. 

Within the 'credit_card' section of etc/profiles.order leave "MV_PAYMENT_MODE" as set,
and add
&set=psp __MV_PAYMENT_PSP__
&set=mv_payment_route authorizenet
(or your preferred gateway instead of authorizenet) as the last entries in the section.
NB: if you are taking offline payments then do not set mv_payment_route here, but instead set in the body
of the 'Buy now' button "mv_payment_route=offlinepayment
                         mv_order_profile=credit_card" 
and install the OfflinePayment.pm module so as to have a named alternative payment route in catalog.cfg.

and then add
Variable MV_PAYMENT_PSP "foo"
to catalog.cfg, where "foo" is the name of your gateway or acquirer, formatted as you want it to appear
on the receipt. Eg, "Bank of America" (rather than boa), "AuthorizeNet" (rather than authorizenet).

In etc/log_transction, immediately after the 
[elsif variable MV_PAYMENT_MODE]
	[calc]
insert this line: 
	undef $Session->{payment_result}{MStatus};

and leave
[elsif variable MV_PAYMENT_MODE] 
as set (contrary to previous revisions of this document) but within the same section change the following 
two instances of [var MV_PAYMENT_MODE] to [value mv_payment_route]. In particular, the setting inside the
[charge route="..] line will specify which payment processor is used for each particular case, and you
need to further modify this line so that it ends up like this:
	[tmp name="charge_succeed"][charge route="[value mv_payment_route]" pprequest="dorequest" amount="[scratch tmp_remaining]" order_id="[value mv_transaction_id]"][/tmp]
If the value of 'mv_payment_route' is set to 'paypalexpress', then this is the one that is run. It is only
called via log_transaction after the customer has returned from Paypal and clicks the 'final' pay button, 
hence this is where the final 'pprequest=dorequest' value is sent. 

Add into the end of the "[import table=transactions type=LINE continue=NOTES no-commit=1]" section
of etc/log_transaction:

psp: [value psp]
pptransactionid: [calc]$Session->{payment_result}{TransactionID}[/calc]
pprefundtransactionid: [calc]$Session->{payment_result}{RefundTransactionID}[/calc]
ppcorrelationid: [calc]$Session->{payment_result}{CorrelationID};[/calc]
pppayerstatus: [value payerstatus]
ppaddressstatus: [value address_status]

and add these 6 new columns into your transactions table as type varchar(256).
You will have records of which transactions went through which payment service providers, as well
as Paypal's returned IDs. The CorrelationID is the one you need in any dispute with them. The payerstatus
and addressstatus results may be useful in the order fulfillment process. 

Add these lines into the body of the 'submit' button that sends the customer to Paypal.
          [run-profile name=paypalexpress]
          [if type=explicit compare="[error all=1 show_var=1 keep=1]"]
          mv_nextpage=ord/checkout
          [/if]
          [charge route="paypalexpress" pprequest="setrequest"]
          mv_todo=return

Create a page 'ord/paypalgetrequest.html', and make it the target of the returnURL from Paypal:
[charge route="paypalexpress" pprequest="getrequest"]
[bounce href="[area ord/paypalcheckout]"]

Create a page 'paypalcheckout.html' in the pages/ord folder. This should display just the basket and address
or whatever you choose for the final pages, plus an IC button with:
			  mv_order_profile=paypalexpress
			  mv_todo=submit
in the body part as the submit button to finalise the order. 'dorequest' is set in log_transaction.

You may then use PaypalExpress for any transaction where the 'mv_order_profile' is set to paypalexpress
but still use the "credit_card" 'mv_order_profile' for other transactions, eg for Authorizenet. Of
course, if PaypalExpress is to be your only payment method, then simply add:
Variable  MV_PAYMENT_MODE paypalexpress
to catalog.cfg just before the paypalexpress Route entries, and this route will be the default.

Note that because Paypal do not recognise UK as a country, only GB, you need to set up shipping in
your country.txt for GB as well as UK. Note also that Paypal do not return the customer's telephone
number by default, so you may need to adjust your order profiles to compensate.

Also note that Paypal requires the user to have cookies enabled, and if they're not will return an error page with no 
indication of the real problem. You may want to warn users of this. 

The flow is: the first button for Paypal sends a request to Paypal to initialise the transaction and gets a token 
back in return. If Paypal fails to send back a token, then the module refreshes that page with an error message 
suggesting that the customer should use your normal payment service provider and shows the cards that you accept. 
Once the token is read, then your customer is taken to Paypal to login and choose his payment method. Once that is 
done, he returns to us and hits the 'paypalgetrequest' page. This gets his full address as held by Paypal, bounces to
the final 'paypalcheckout' page and populates the form with his address details. If you have both shipping
and billing forms on that page, the shipping address will be populated by default but you may force
the billing form to be populated instead by sending
<input type=hidden name=pp_use_billing_address value=1>
at the initial stage. Then the customer clicks the final 'pay now' button and the transaction is done.


Options that may be set either in the route or in the page:
 * reqconfirmshipping - this specifies that a Paypal customer must have his address 'confirmed'
 * addressoverride - this specifies that you will ship only to the address IC has on file (including
   the name and email); your customer needs to login to IC first before going to Paypal
 * use_billing_override - sends billing address instead of shipping to PayPal (use with addressoverride)
 * other options are also settable.

Testing: while the obvious test choice is to use their sandbox, I've always found it a bit of a dog's breakfast
   and never trusted it. Much better to test on the live site, and just recyle money between your personal and
   business accounts at minimal cost to yourself, but with the confidence of knowing that test results are correct.


Recurring Payments:
you need a number of new fields in the products table for the parameters required by
Paypal, viz:
rpdeposit: gross amount for a deposit
rpdepositfailedaction: ContineOnFailure - Paypal will added failed amount to outstanding balance
  CancelOnFailure (or empty) - Paypal sets status to Pending till inital payment completes, then 
  sends IPN to notify of either the status becoming Active or the payment failing
rptrialamount: nett amount
rptrialtaxamount:
rptrialshippingamount:
rptrialperiod: one of Day, Week, SemiMonth, Month.
rptrialfrequency: integer, number of periods between payments, eg "every 2 weeks"
rptrialtotalcycles: total number of trial payments before regular payments start
rpamount: nett amount for regular payments
rptaxamount:
rpshippingamount:
rpperiod: one of Day, Week, SemiMonth, Month
rpfrequency: integer, number of periods between payments, eg "every 2 weeks"
  NB:/ multiple of period * frequency cannot be greater than one year as maximum interval between payments
rptotalcycles: total number of regular payments - can be empty
rpstartdate: leave empty to use current date. An absolute date must be in the 2011-02-25T00:00:00Z
  format. An interval from the current date should use "2 weeks", "5 days" as the format, where
  the period can be any given above except SemiMonth (this is always billed on the 1st and
  15th of the month)
rpmaxfailedpayments: number of failures before the agreement is automatically cancelled
rpautobillarrears: NoAutoBill, AddToNextBilling - Paypal automatically takes requested action

Displaying the recurring payment amounts taken at order time is quite straightforward - if you want
to do that then put the total to be taken into the price field, nett of tax or shipping.
You could then modify the receipt page and receipt emails with a new field something like:
[if-item-field rpperiod] 
[tmp][item-calc]$rpno++[/item-calc][/tmp]
Ref: [value mv_order_number]-sub[item-calc]$rpno[/item-calc]
<br>ID: [data table=transactions col=order_id key='[value mv_order_number]-sub[item-calc]$rpno[/item-calc]']
<br>Status: [data table=transactions col=status key='[value mv_order_number]-sub[item-calc]$rpno[/item-calc]'] 
[/if-item-field]
Where:
ID = rpprofileid (the primary identifier on the customer's Paypal account page),
Ref = rpprofilereference (your order number, appended with '-subn' where n is a number from 1 to 10),
Status = rpprofilestatus (Pending or Active, but Cancelled and Suspended are also valid)

If you want to log the key values for each recurring profile, then add these fields to the orderline table:
rpperiod varchar(32)
rpfrequency varchar(32)
rpprofileid  varchar(64)
rpprofilereference varchar(64)
rpprofilestatus varchar(32)
rpgrossamount varchar(32)
rpcorrelationid varchar(64)

and at the beginning of the orderline section of log_transaction, around line 462, add
[calc] $rpno = 0; [/calc]
just before "[item-list] Added [item-code] to orderline:"
and then between "[item-list]" and "[import table=orderline ...]" add:

[if-item-field rpperiod]
[item-calc]$rpno++[/item-calc]
[seti rpprofileid][data table=transactions col=order_id key='[value mv_order_number]-sub[item-calc]$rpno[/item-calc]'][/seti]
[charge route="[value mv_payment_route]" pprequest="getrpdetails" rpprofileid="[scratchd rpprofileid]"]
[/if-item-field]

and then between [import ..] and [/import]
add:
rpprofileid: [scratchd rpprofileid]
rpprofilereference: [scratchd rpprofilereference]
rpprofilestatus: [scratchd rpprofilestatus]
rpgrossamount: [scratchd rpgrossamount]
rpperiod: [scratchd rpperiod]
rpfrequency: [scratchd rpfrequency]
rpcorrelationid: [scratchd rpcorrelationid]

Calling 'getrpdetails' as above returns everything Paypal holds about that transaction and makes it available
in scratch space:
rpcorrelationid
rpprofilereference
rpprofileid
rpdescription
rpprofilestatus
rpsubscribername
rpstartdate (formatted for [convert-date])
rptaxamount
rpshippingamount
rpamount
rpgrossamount (including tax and shipping, amount for each regular payment)
rpfrequency
rpperiod
rptotalycles (total committed to)
rpnextbillingdate (formatted for [convert-date])
rpcyclesmade (number of payments made)
rpcyclesfailed (number of payaments failed)
rpcyclesremaining (number of payments left to go)
rparrears (amount oustanding)
rpmaxfailedpayments (number of failed payments allowed by merchant)
rptrialamount
rptrialtaxamount
rptrialshippingamount
rptrialfrequency 
rptrialperiod
rptrialtotalcycles
rptrialgrossamount 
rpfinalpaymentduedate
rpregularamountpaid (amount paid to date)
rptrialamountpaid

ItemDetails now passed and displayed in the 'new style' Paypal checkout. Discounts/coupons 
are not passed, as there is too much scope for error with currency conversions etc which 
would cause Paypal to reject the transaction, but instead a note to the buyer will be displayed if 
the value of pp_discount_note is passed as true.

The order number is now set prior to going to Paypal, as they need a Profile Reference
and the most sensible way to handle this is to set the order number and append a unique 
reference for each recurring agreement set up. This also means that the customer's Paypal
account page will show the IC order number as well as Paypal's ProfileID for simpler correlation.

You may setup a recurring billing agreement and profile with or without an accompanying
purchase or possibly without any initial payment - if without then the amount sent is zero. 
# ### FIXME 
To allow Interchange to log a zero amount,
change log_transaction to: 
[unless scratch allowzeroamount]
  [if scratch tmp_remaining == 0]
	Fully paid by payment cert.
  [/if] 
[/unless]
around line 80, and around line 221
[if scratchd ordernumberalreadyset]
  Order number already set by PaypalExpress
[else]
Set order number in values: [value
.....
						$Session->{mv_order_number} = $Values->{mv_order_number};
					[/calc]
[/else]
[/if]
to stop IC setting the order number again

There are also a number of functions which could be handled by an admin panel or virtual
terminal. 

Manage Recurring Payments:
this will cancel, suspend or reactive a profile. It expects to find the customer's
ProfileID in the orderline table as rpprofileid, and will return a new correlationid.
Send managerp_cancel, managerp_suspend, or managerp_reactivate from your virtual
terminal as a 'pprequest' along with the customer's profileID as an IC 'value'.

Modify Recurring Payments;
this allows you to add cycles to the payment profile, change addresses, change amount
to be paid. You cannot increase the amount by more than 20% pa. 

Masspay:
this works for a list of up to 250 recipients, but this function is apparently being phased
out - certainly in the UK they will not enable masspay any more. Note that the currency 
sent must be the same as the currency the sending account is in, and you only get one
ID returned for the entire masspayment. The module expects a list as [value vtmessage], 
consisting of four comma-separated and quoted fields per record, one record per line:
"email address (or paypal ID)","amount (without currency symbols)","unique ID","notes"
The notes field may be empty but must be quoted. You may also send a subject for the email 
that Paypal sends to each recipient, as [value email_subject], defaulting to 'Paypal payment' 
if not set. All recipients must be either email addresses or paypal IDs, not a mixture of both. 
All payments must be in the same currency for each list sent, and the currency set is the same 
as taken by the main routines; see above.

Other functions added, as Route parameters or IC or HTML values
allowed_payment_method: Default = any; AnyFundingSource = any chosen by buyer irrespective of profile;
	  InstantOnly = only instant payments; InstantFundingSource  = only instant methods, blocks 
	  echeck, meft, elevecheck
soft_descriptor: shown on customer's card receipt as transaction description
brand_name: overrides business name shown to customer
gift_message_enable: 0 or 1
gift_receipt_enable: 0 or 1
gift_receipt_enable: 0 or 1
gift_wrap_name: string
buyer_email_optin: 0 or 1
survey_enable: 0 or 1
allow_push_funding: 0 or 1
allow_note: 0 or 1
service_phone: displayed to customer at PaypalExpress
notify_url: for IPN callbacks

=head1 Bugs
Including total_type causes all child elements of the initial Set request to be ignored, thereby
removing recurring payment BillingAgreeements and all payment detail items from view, which
in turn means there is no order total and so the request is rejected.

Including brand_name does the same as above but only when a BillingAgreeement is included in the
request - hence the module excludes this setting when a BillingAgreeement is included, but sets
it otherwise. 





=head1 Changelog
version 1.1.0 October 2011
	- major update:
	- enabled 'item details' in initial request, so the new-style Paypal checkout page shows
	  an itemised basket
	- updated masspay to handle multiple recipients properly
	- added refunds, either full or partial
	- added 'getbalance', to get the balance of the calling account or any other account for
	  which the credentials are known. If account is multi-currency, then all balances and currencies
	  are displayed in a scratch value.
	- added 'sendcredit', which sends funds to a specified credit card. You need to know the full
	  billing address and cv2 number, and need to get Paypal to enable this function on your account
	- added repeat payments, ie recurring billing. Up to the Paypal limit of 10 billing agreements
	  may be set up in one request. Billing agreements may be set up with optional trial periods and
	  deposits, and may be setup with or without an accompanying standard purchase. 
	- added function to manage repeat payments, ie suspend, reactivate, or cancel
	- added function to modify repeat payments, ie to alter the billing/shipping address or name,
	  to alter the amount or period etc
	- added function to get details of a repeat payments billing agreement, and display the results
	  in scratch space including date of next payment, amount paid to date, etc
	- added function to bill any outstanding arrears in a billing agreement
	- requires Date::Calc now

version 1.0.8 July 2010
	- fixed bug in handling of multiple PP error messages

version 1.0.7 December 2009
	- another variation in Canadian Province names has just come to light, whereby they sometimes send
	  the 2 letter code with periods, eg B.C. as well as BC. Thanks to Steve Graham for finding this
	- patch to allow use of the [assign] tag in shipping
	- patch to allow 'use_billing_override' to send billing addresses
	- patch to display Long rather than Short PP error message to customers
	  Thanks to Josh Lavin for these last three
	
version 1.0.6 September 2009
	- added 'use strict' and fixed odd errors (and removed giropay vestiges that belong in next version)
	- made itemdetails loop through basket properly
	- added Fraud Management Filters return messages to optional charge parameters
version 1.0.5, June 2009
	- fixed bug with Canadian provinces: PP were sending shortened versions of 2 province names, and also 
	  sometimes sending the 2 letter code (possibly from older a/cs) rather than the full name. Thanks to 
	  Steve Graham for finding this.
version 1.0.4, May 2009
	- re-wrote documentation, including revised and simplified method of co-operating with other payment
	  systems in log_transaction. 

version 1.0.3, 1.02.2009
	- fixed bug in handling of thousands separator

version 1.0.2, 22.01.2009 
	- conversion of Canadian province names to 2 letter variant is now the default
	- fixed bug with conversion of Canadian province names to 2 letter variant
	- changed method of reading value of pprequest
	- added failsafe logging to orders/paypal/ in case of order route failure
	- fixed bug whereby PP returns billing name in a shipping address
	- added note to docs re PP requiring cookie
	- altered internal redirection code to better handle absence of cookies (thanks to Peter Ajamian for heads-up)
	- altered docs to reflect the new sandbox (thanks to Josh Lavin for the heads-up on that)
	- TODO: as the new API now includes a SOAP integration of recurring/subscription billing, need 
	        to convert existing name=value pair IPN module and integrate into this module. Will add
	        masspay, refund and other functions at the same time. 

version 1.0.1, 24.05.2008 
	- added error message to IC session for when Paypal returns error message instead of token.
	- added option to convert Canadian state/province names to an uppercased 2 letter variant, so
            as to agree with Interchange's de facto requirement for this.
=back

=head1 AUTHORS

Lyn St George <info@zolotek.net>

=cut

BEGIN {
	eval {
		package Vend::Payment;
		require SOAP::Lite or die __PACKAGE__ . " requires SOAP::Lite";
# without this next it defaults to Net::SSL which may crash
		require IO::Socket::SSL or die __PACKAGE__ . " requires IO::Socket::SSL";
		require Net::SSLeay;
		require LWP::UserAgent;
		require HTTP::Request;
        require Date::Calc;
		use Date::Calc qw(Add_Delta_YMD Today Today_and_Now);
		use POSIX 'strftime';
	};

		$Vend::Payment::Have_Net_SSLeay = 1 unless $@;

	if ($@) {
		$msg = __PACKAGE__ . ' requires SOAP::Lite and IO::Socket::SSL ' . $@;
		::logGlobal ($msg);
		die $msg;
	}

	::logGlobal("%s v1.1.0m 20120121 payment module loaded",__PACKAGE__)
		unless $Vend::Quiet or ! $Global::VendRoot;
}

package Vend::Payment;
#use SOAP::Lite +trace; # ### debugging only ###
use strict;

    my (%result, $header, $service, $version, $xmlns, $currency);

sub paypalexpress {
    my ($token, $request, $method, $response, $in, $opt, $actual, $basket, $itemCode, $tax, $invoiceID);
	my ($item, $itm, $basket, $setrpbillagreement, $rpprofile, $db, $dbh, $sth);

	foreach my $x (@_) {
		    $in = { 
		    		pprequest => $x->{'pprequest'},
		    	   }
	}

#::logDebug("PP".__LINE__.": sandbox=$::Values->{ppsandbox} ". charge_param('sandbox'). "req=".charge_param('pprequest'));
	my $pprequest   = charge_param('pprequest') || $::Values->{'pprequest'} || $in->{'pprequest'} || 'setrequest'; # 'setrequest' must be the default for standard Paypal. 
	my $sandbox     = charge_param('sandbox') || $::Values->{'sandbox'} || $::Values->{'ppsandbox'} || ''; # 1 or true to use for testing
	   $sandbox     = '' unless $sandbox =~ /sandbox|1/;
	   $sandbox     = "sandbox." if $sandbox =~ /sandbox|1/;
	   $::Values->{'ppsandbox'} = $::Values->{'sandbox'} = '';
	   $::Scratch->{'mstatus'} = '';
#::logDebug("PP".__LINE__.": sandbox=$sandbox passwd=".charge_param('password')." sig=".charge_param('signature'));

	   $currency = $::Values->{'iso_currency_code'} || $::Values->{'currency_code'} || $::Scratch->{'iso_currency_code'}  || 
				   $Vend::Cfg->{'Locale'}{'iso_currency_code'} || charge_param('currency')  || $::Variable->{MV_PAYMENT_CURRENCY} || 'USD';
	   $::Scratch->{'iso_currency_code'} ||= $currency;

# Credentials, prefixed with lower-cased account name if using 'getbalance' for more than one account
	my $account     = lc($pprequest) if $pprequest =~ /getbalance_/ || '';
	   $account     =~ s/getbalance_//;
	   $account     .= '_' if length $account;
	   $sandbox     = "sandbox." if $account =~ /sandbox/;
    my ($username, $password, $signature);
    if (length $sandbox && charge_param('sandbox_id')) {
        $username   = charge_param('sandbox_id');
        $password   = charge_param('sandbox_password');
        $signature  = charge_param('sandbox_signature');
    }
    else {
        $username    = charge_param($account . 'id');
        $password    = charge_param($account . 'password');
        $signature   = charge_param($account . 'signature');
    }

    unless ($username && $password && $signature) {
         return (
			MStatus => 'failure-hard',
			MErrMsg => errmsg('Bad credentials'),
		);
    }
    
	my $ppcheckreturn = $::Values->{'ppcheckreturn'} || 'ord/checkout';
	my $checkouturl = $::Tag->area({ href => "$ppcheckreturn" });
#::logDebug("PP".__LINE__.": req=$pprequest; sandbox=$sandbox;");
#::logDebug("PP".__LINE__.": amt=" .Vend::Interpolate::total_cost() . "-" . charge_param('amount') ."-". $::Values->{'amount'});

#	my $amount =  charge_param('amount') || Vend::Interpolate::total_cost() || $::Values->{amount}; # required
	my $amount =  charge_param('amount') || Vend::Interpolate::total_cost() || $::Values->{'amount'}; # required
	   $amount =~ s/^\D*//g;
	   $amount =~ s/\s*//g;
	   $amount =~ s/,//g;

# for a SET request
	my $host               = charge_param('host') ||  'api-3t.paypal.com'; #  testing 3-token system is 'api-3t.sandbox.paypal.com'.
	   $host               = 'api-3t.sandbox.paypal.com' if length $sandbox;
	my $ipnhost			   = 'www.paypal.com';
	   $ipnhost            = 'www.sandbox.paypal.com' if length $sandbox;
	my $setordernumber     = charge_param('setordernumber') || '1'; # unset to revert to using a temp order number until order settled
	   $invoiceID          = $::Values->{'inv_no'} || $::Values->{'mv_transaction_id'} || $::Values->{'order_number'} || '' unless $setordernumber; # optional
	my $ordercounter       = charge_param('order_counter') || 'etc/order.number';
	my $returnURL          = charge_param('returnurl') or die "No return URL found\n"; # required
	my $cancelURL          = charge_param('cancelurl') or die "No cancel URL found\n"; # required
	my $notifyURL          = charge_param('notifyurl') || ''; # for IPN
	my $maxAmount          = $::Values->{'maxamount'} || $amount * '2';  # optional
	   $maxAmount          = sprintf '%.2f', $maxAmount;
	my $orderDescription   = '';
	my $address            = '';
	my $reqConfirmShipping = $::Values->{'reqconfirmshipping'} || charge_param('reqconfirmshipping') || ''; # you require that the customer's address must be "confirmed"
	my $returnFMFdetails   = $::Values->{'returnfmfdetails'} || charge_param('returnfmfdetails') || '0'; # set '1' to return FraudManagementFilter details
	my $noShipping         = $::Values->{'noshipping'} || charge_param('noshipping') || ''; # no shipping displayed on Paypal pages
	my $addressOverride    = $::Values->{'addressoverride'} || charge_param('addressoverride') || ''; # if '1', Paypal displays address given in SET request, not the one on Paypal's file

# new style checkout 'co-branding' options
	my $localeCode         = $::Values->{'localecode'} || $::Session->{'mv_locale'} || charge_param('localecode') || 'US';
	my $pageStyle          = $::Values->{'pagestyle'} || charge_param('pagestyle') || ''; # set in Paypal account
	my $headerImg          = $::Values->{'headerimg'} || charge_param('headerimg') || ''; # max 750x90, classic checkout, left-aligned, from your secure site
	my $logoImg            = $::Values->{'logoimg'} || charge_param('logoimg') || ''; # max 190x60, 'new style checkout', centred in 'cart area', from your secure site
	my $cartBorderColor    = $::Values->{'cartbordercolor'} || charge_param('cartbordercolor'); # hex code, without '#'
	my $headerBorderColor  = $::Values->{'headerbordercolor'} || charge_param('headerbordercolor') || '';
	my $headerBackColor    = $::Values->{'headerbackcolor'} || charge_param('headerbackcolor') || '';
	my $payflowColor       = $::Values->{'payflowcolor'} || charge_param('payflowcolor') || '';

	my $paymentAction      = $::Values->{'paymentaction'} || charge_param('paymentaction') || 'Sale'; # others: 'Order', 'Authorization'
	my $buyerEmail         = $::Values->{'buyeremail'} || '';
	my $custom             = $::Scratch->{'mv_currency'} || $::Scratch->{'mv_locale'}; 
       $custom           ||= 'en_' . lc(substr($currency,0,1));
# these next taken from IC after customer has logged in, and used in '$addressOverride'
	my $usebill  = $::Values->{'use_billing_override'} || charge_param('use_billing_override');
	my $name     = $usebill ? "$::Values->{'b_fname'} $::Values->{'b_lname'}" || '' : "$::Values->{'fname'} $::Values->{'lname'}" || '';
	my $address1 = $usebill ? $::Values->{'b_address1'} : $::Values->{address1};
	my $address2 = $usebill ? $::Values->{'b_address2'} : $::Values->{address2};
	my $city     = $usebill ? $::Values->{'b_city'} : $::Values->{city};
	my $state    = $usebill ? $::Values->{'b_state'} : $::Values->{state};
	my $zip      = $usebill ? $::Values->{'b_zip'} : $::Values->{zip};
	my $country  = $usebill ? $::Values->{'b_country'} : $::Values->{country};
	   $country  = 'GB' if ($country eq 'UK'); # plonkers reject UK
	my $phone    = $::Values->{'phone_day'} || $::Values->{'phone_night'};
	   
# for a Do request, and Set with item details
	my $dsmode 	      = $::Variable->{'DSMODE'}; # for any custom shipping tags
	my $itemTotal     = $::Values->{'itemtotal'} || Vend::Interpolate::subtotal() || '';
	   $itemTotal     = sprintf '%.2f', $itemTotal;
	my $shipTotal     = $::Values->{'shiptotal'} || Vend::Interpolate::tag_shipping() || '' unless  $::Variable->{'DSMODE'};
	   $shipTotal     = $::Tag->$dsmode() if $::Variable->{'DSMODE'};
	   $shipTotal     = sprintf '%.2f', $shipTotal;
	my $taxTotal      = $::Values->{'taxtotal'} || Vend::Interpolate::salestax() || '';
	   $taxTotal      = sprintf '%.2f', $taxTotal;
	my $handlingTotal = $::Values->{'handlingtotal'} || Vend::Ship::tag_handling() || '';
	   $handlingTotal = sprintf '%.2f', $handlingTotal;

	my $buttonSource        = $::Values->{'buttonsource'} || charge_param('buttonsource') || ''; # for third party source
	my $paymentDetailsItem  = $::Values->{'paymentdetailsitem'} || charge_param('paymentdetailsitem') || ''; # set '1' to include item details
	my $transactionID       = $::Values->{'transactionid'} || ''; # returned upon success, but not for recurring billing, only the correlationid
	my $correlationID       = $::Values->{'correlationid'} || ''; # use for any dispute with Paypal
	my $refundtransactionID = $::Values->{'refundtransactionid'} || ''; # log for reference
	my $quantity            = $::Tag->nitems() || '1';

	my $itemised_basket_off = delete $::Values->{'itemised_basket_off'} || charge_param('itemised_basket_off');

# if $paymentDetailsItem is set, then need to pass an item amount to keep Paypal happy
	my $itemAmount   = $amount / $quantity;
	   $itemAmount   = sprintf '%.2f', $itemAmount;
	   $amount       = sprintf '%.2f', $amount;
	my $receiverType = $::Values->{'receiverType'} || charge_param('receivertype') || 'EmailAddress'; # used in MassPay
	   $version      = '74.0';
	my $order_id  = gen_order_id($opt);
#::logDebug("PP".__LINE__.": oid=$order_id; amount=$amount, itemamount=$itemAmount; tax=$taxTotal, ship=$shipTotal, hdl=$handlingTotal");

# new fields for v 1.1.0 and API v 74
	my $softDescriptor    = $::Values->{'soft_descriptor'} || charge_param('soft_descriptor'); # appears on customer's card statement
	my $allowNote         = $::Values->{'allow_note'} || charge_param('allow_note'); # allow customer to enter note at Paypal
	my $brandName         = $::Values->{'brand_name'} || charge_param('brand_name'); # max 127 chars, over-rides the business name at Paypal
	my $servicePhone      = $::Values->{'service_phone'} || charge_param('service_phone'); # displayed to customer
	my $giftMessageEnable = $::Values->{'gift_message_enable'} || charge_param('gift_message_enable'); # 0 or 1
	my $giftReceiptEnable = $::Values->{'gift_receipt_enable'} || charge_param('gift_receipt_enable'); # 0 or 1
	my $giftWrapEnable    = $::Values->{'gift_wrap_enable'} || charge_param('gift_wrap_enable'); # 0 or 1
	my $giftWrapName      = $::Values->{'gift_wrap_name'}; 
	my $giftWrapAmount    = $::Values->{'gift_wrap_amount'};
	my $buyerEmailOptin   = $::Values->{'buyer_email_optin'} || charge_param('buyer_email_optin');  # 0 or 1
	my $surveyEnable      = $::Values->{'survey_enable'} || charge_param('survey_enable'); # 0 or 1
	my $surveyQuestion    = $::Values->{'survey_question'} || charge_param('survey_question');
	my $surveyChoice      = $::Values->{'survey_choice'} || charge_param('survey_choice');
	my $allowPushFunding  = $::Values->{'allow_push_funding'} || charge_param('allow_push_funding'); # 0 or `
	my $allowedPayMethod  = $::Values->{'allowed_payment_method'} || charge_param('allowed_payment_method'); #
	my $landingPage       = $::Values->{'landing_page'} || charge_param('landing_page');
	my $solutionType      = $::Values->{'solution_type'} || charge_param('solution_type');
	my $totalType         = $::Values->{'total_type'} || charge_param('total_type') || 'EstimatedTotal'; # or 'Total' if is known accurately



	# for Giropay
	my $giropaySuccessURL = $::Values->{'giropay_success_url'} || charge_param('giropay_success_url');
	my $giropayCancelURL  = $::Values->{'giropay_cancel_url'} || charge_param('giropay_cancel_url');
	my $BanktxnPendingURL = $::Values->{'bnktxn_pending_url'} || charge_param('bnktxn_pending_url');
	my $giropayaccepted   = $::Values->{'giropay_accepted'} || charge_param('giropay_accepted') || '1';
	my $giropayurl        = "https://www." . $sandbox . "paypal.com/cgi-bin/webscr?cmd=_complete-express-checkout";

#-----------------------------------------------------------------------------------------------
	# for operations through the payment terminal, eg 'masspay', 'refund' etc
	my  $refundType    = $::Values->{'refundtype'} || 'Full'; # either 'Full' or 'Partial'
	my  $memo          = $::Values->{'memo'} || '';
	my  $orderid       = $::Values->{'mv_order_id'} || '';
	my  $emailSubject  = $::Values->{'emailsubject'} || ''; # subject line of email
	my  $receiverEmail = $::Values->{'receiveremail'} || ''; # address of refund recipient


        $xmlns = 'urn:ebay:api:PayPalAPI';

	    $service = SOAP::Lite->proxy("https://$host/2.0/")->uri($xmlns);
	    # Ignore the paypal typecasting returned
	    *SOAP::Deserializer::typecast = sub {shift; return shift};

#-------------------------------------------------------------------------------------------------
### Create the Security Header
#
	    $header = SOAP::Header->name("RequesterCredentials" =>
					\SOAP::Header->value(
						SOAP::Data->name("Credentials" =>
							\SOAP::Data->value(
								SOAP::Data->name("Username" => $username )->type("xs:string"),
								SOAP::Data->name("Password" => $password )->type("xs:string"),
								SOAP::Data->name("Signature" => $signature)->type("xs:string")
							)
						)
						 ->attr({xmlns=>"urn:ebay:apis:eBLBaseComponents"})
					)
				)
				 ->attr({xmlns=>$xmlns})->mustUnderstand("1");


#--------------------------------------------------------------------------------------------------
### Create a SET request and method, and read response
#
	my ($item,$itm,@pditems,@pdi,$pdi,$pdiamount,$itemtotal,$pdisubtotal,$cntr,$pditotalamount,$rpamount,$itemname);

	if ($pprequest eq 'setrequest') {
	  if (charge_param('setordernumber') == '1') {
		  $invoiceID = $::Values->{'inv_no'} || Vend::Interpolate::tag_counter( $ordercounter );
		  $::Values->{'mv_order_number'} = $::Session->{'mv_order_number'} = $invoiceID;
		  $::Scratch->{'ordernumberalreadyset'} = '1';
	  }

# start with required elements, add optional elements if they exist
		   my @setreq = (
				       SOAP::Data->name("ReturnURL" => $returnURL)->type(""),
				       SOAP::Data->name("CancelURL" => $cancelURL)->type(""),
						);
		push @setreq,  SOAP::Data->name("ReqConfirmShipping" => $reqConfirmShipping)->type("xs:string") if $reqConfirmShipping;
		push @setreq,  SOAP::Data->name("NoShipping" => $noShipping)->type("xs:string") if $noShipping;
		push @setreq,  SOAP::Data->name("AddressOverride" => $addressOverride)->type("xs:string") if $addressOverride;
		push @setreq,  SOAP::Data->name("PageStyle" => $pageStyle)->type("xs:string") if $pageStyle;
		push @setreq,  SOAP::Data->name("BuyerEmail" => $buyerEmail)->type("xs:string") if $buyerEmail;
		push @setreq,  SOAP::Data->name("cpp-header-image" => $headerImg)->type("xs:string") if $headerImg;
		push @setreq,  SOAP::Data->name("cpp-logo-image" => $logoImg)->type("xs:string") if $logoImg;
		push @setreq,  SOAP::Data->name("cpp-header-border-color" => $headerBorderColor)->type("xs:string") if $headerBorderColor;
		push @setreq,  SOAP::Data->name("cpp-header-back-color" => $headerBackColor)->type("xs:string") if $headerBackColor;
		push @setreq,  SOAP::Data->name("cpp-payflow-color" => $payflowColor)->type("xs:string") if $payflowColor;
		push @setreq,  SOAP::Data->name("cpp-cart-border-color" => $cartBorderColor)->type("xs:string") if $cartBorderColor;
		push @setreq,  SOAP::Data->name("LandingPage" => $landingPage)->type("ebl:LandingPageType") if $landingPage;
		push @setreq,  SOAP::Data->name("SolutionType" => $solutionType)->type("ebl:SolutionTypeType") if $solutionType;
		push @setreq,  SOAP::Data->name("MaxAmount" => $maxAmount)->attr({"currencyID" => $currency})->type("ebl:BasicAmountType") if $maxAmount;
		push @setreq,  SOAP::Data->name("CustomerServiceNumber" => $servicePhone)->type("xs:string") if $servicePhone;
		push @setreq,  SOAP::Data->name("GiftMessageEnable" => $giftMessageEnable)->type("xs:string") if $giftMessageEnable; # 0 or 1
		push @setreq,  SOAP::Data->name("GiftReceiptEnable" => $giftReceiptEnable)->type("xs:string") if $giftReceiptEnable; # 0 or 1
		push @setreq,  SOAP::Data->name("GiftWrapEnable" => $giftWrapEnable)->type("xs:string") if $giftWrapEnable; # 0 or 1
		push @setreq,  SOAP::Data->name("GiftWrapName" => $giftWrapName)->type("xs:string") if $giftWrapName; # 25 chars
		push @setreq,  SOAP::Data->name("GiftWrapAmount" => $giftWrapAmount)->attr({"currencyID" => $currency})->type("ebl:BasicAmountType") if $giftWrapAmount;
		push @setreq,  SOAP::Data->name("BuyerEmailOptinEnable" => $buyerEmailOptin)->type("xs:string") if $buyerEmailOptin; # 0 or 1
		push @setreq,  SOAP::Data->name("SurveyEnable" => $surveyEnable)->type("xs:string") if $surveyEnable; # 0 or 1
		push @setreq,  SOAP::Data->name("SurveyQuestion" => $surveyQuestion)->type("xs:string") if $surveyQuestion; # max 50 chars
		push @setreq,  SOAP::Data->name("SurveyChoice" => $surveyChoice)->type("xs:string") if $surveyChoice; # max 15 chars
		push @setreq,  SOAP::Data->name("LocaleCode" => $localeCode)->type("xs:string") if $localeCode;
		push @setreq,  SOAP::Data->name("AllowNote" => $allowNote)->type("xs:string") if defined $allowNote; # 0 or 1
#		push @setreq,  SOAP::Data->name("TotalType" => $totalType)->type("") if $totalType; # ### crashes ... ###


#::logDebug("PP".__LINE__.": itemTotal=$itemTotal; taxTotal=$taxTotal");

# now loop through the basket and put every item into iterated PaymentDetailsItem blocks, and 
# recurring payments items into iterated BillingAgreeement blocks. Explicit arrays not needed.

		  foreach  $item (@{$::Carts->{'main'}}) {
			my $rpamount_field = 'rpamount_' . lc($currency) || 'rpamount';
			  $itm = {
					  sku => $item->{'code'},
					  quantity => $item->{'quantity'},
					  amount => Vend::Data::item_price($item),
					  description => Vend::Data::item_field($item, 'description'),
					  title => Vend::Data::item_field($item, 'title'),
					  rpamount => Vend::Data::item_field($item, 'rpamount'),
					  rpamount_field => Vend::Data::item_field($item, $rpamount_field),
					  };

			$itemname = $itm->{'title'} || $itm->{'description'};
			$pdiamount = $itm->{'amount'};
			$pdiamount = sprintf '%.02f', $pdiamount;
			$pdisubtotal = $pdiamount * $itm->{'quantity'};
#::logDebug("PP".__LINE__.": pdi: sku=$itm->{sku}, desc=$itm->{description}, qty=$itm->{quantity}; amt=$itm->{amount}; rpamt=$itm->{rpamount}; fld=$rpamount_field; cur=$currency; payact=$paymentAction");

		    $rpamount = $itm->{'rpamount_field'} || $itm->{'rpamount'};
	  if ($rpamount) {
#::logDebug("PP".__LINE__.": cntr=$cntr;  rpamount=$rpamount");	

            $setrpbillagreement = (
					   SOAP::Data->name("BillingAgreementDetails" =>
					   \SOAP::Data->value(
					    SOAP::Data->name("BillingType" => 'RecurringPayments')->type(""),
						SOAP::Data->name("BillingAgreementDescription" => $itm->{'description'})->type(""),
						      )
						    )->type("ns:BillingAgreementDetailsType"),
						);

		  if ($cntr > '9') {
			$::Session->{'errors'}{'Paypal'} = "Paypal will not accept more than ten subscriptions in one order - please remove some and purchase them in
			a second order";
			return();
		  };
	  $cntr++;
	
	$::Scratch->{'allowzeroamount'} = '1'; # use in log_transaction
	push @setreq, $setrpbillagreement;

	  } # if RecPay item in basket loop
#
# Finished with BillingAgreeements, now for PaymentDetailsItem in basket loop
# Separate block for each item: also include those which are RecPay items
#
			  $pditotalamount += $pdisubtotal; # to overcome rounding errors in currency conversions
#::logDebug("PP".__LINE__.":amt=$amount; pditotalamount=$pditotalamount; pdiamount=$pdiamount");

		       @pdi = SOAP::Data->name("Name" => $itemname)->type("");
	      push @pdi, SOAP::Data->name("Amount" => $pdiamount)->attr({"currencyID" => $currency})->type("");
	      push @pdi, SOAP::Data->name("Number" => $itm->{'sku'})->type("");
	      push @pdi, SOAP::Data->name("Description" => $itm->{'description'})->type("") if $itm->{'description'};
	      push @pdi, SOAP::Data->name("Quantity" => $itm->{'quantity'})->type("") if $itm->{'quantity'};
	      push @pdi, SOAP::Data->name("ItemWeight" => $itm->{'weight'})->type("") if $itm->{'weight'};
	      push @pdi, SOAP::Data->name("ItemWidth" => $itm->{'width'})->type("") if $itm->{'width'};
	      push @pdi, SOAP::Data->name("ItemLength" => $itm->{'length'})->type("") if $itm->{'length'};
	      push @pdi, SOAP::Data->name("ItemHeight" => $itm->{'height'})->type("") if $itm->{'height'};
	      push @pdi, SOAP::Data->name("ItemURL" => $itm->{'murl'})->type("") if $itm->{'url'};
	      push @pdi, SOAP::Data->name("ItemCategory" => $itm->{'category'})->type("") if $itm->{'category'}; # required as 'Digital' for digital goods, else optional as 'Physical'

		 $pdi  = (
	                SOAP::Data->name("PaymentDetailsItem" =>
	                \SOAP::Data->value(
					  @pdi,
	                    )
	                  )->type("ebl:PaymentDetailsItemType"),
	                );

		  push @pditems, $pdi unless $itemised_basket_off == '1';
			$cntr++;
	  } # foreach item in basket

#
# Finished basket loop for each item, now for PaymentDetails
#
#::logDebug("PP".__LINE__.": vship=$::Values->{'shiptotal'}; tag=" .Vend::Interpolate::tag_shipping());
# calculate here so as to avoid rounding errors and rejection at Paypal
	my $itemtotal     = $pditotalamount;
	   $itemtotal     = sprintf '%.2f', $itemtotal;
	my $shiptotal     = $::Values->{'shiptotal'} || Vend::Interpolate::tag_shipping() || '' unless  $::Variable->{'DSMODE'};
	   $shiptotal     = $::Tag->$dsmode() if $::Variable->{'DSMODE'};
	   $shiptotal     = sprintf '%.2f', $shiptotal;
	my $handlingtotal = $::Values->{'handlingtotal'} || Vend::Ship::tag_handling() || '';
	   $handlingtotal = sprintf '%.2f', $handlingtotal;
	my $taxtotal      = $::Values->{'taxtotal'} || Vend::Interpolate::salestax() || '';
	   $taxtotal      = sprintf '%.2f', $taxtotal;
#::logDebug("PP".__LINE__.": tax=$::Values->{taxtotal}; ". Vend::Interpolate::salestax());
	   $amount = $itemtotal + $shiptotal + $taxtotal + $handlingtotal;

           my $shiptoaddress = (
                       SOAP::Data->name("ShipToAddress" =>
                       \SOAP::Data->value(
                        SOAP::Data->name("Name" => $name)->type(""),
                        SOAP::Data->name("Street1" => $address1)->type(""),
                        SOAP::Data->name("Street2" => $address2)->type(""),
                        SOAP::Data->name("CityName" => $city)->type(""),
                        SOAP::Data->name("StateOrProvince" => $state)->type(""),
                        SOAP::Data->name("PostalCode" => $zip)->type(""),
                        SOAP::Data->name("Country" => $country)->type(""),
                        SOAP::Data->name("Phone" => $phone)->type(""),
                            )
                          )
                        ) if length $address1;

		my @pd =  SOAP::Data->name("OrderTotal" => $amount)->attr({"currencyID" => $currency})->type('');
		push @pd, SOAP::Data->name("ItemTotal" => $itemtotal)->attr({"currencyID" => $currency})->type("") if $itemtotal;
		push @pd, SOAP::Data->name("TaxTotal" => $taxtotal)->attr({"currencyID" => $currency})->type("") if $taxtotal;
		push @pd, SOAP::Data->name("ShippingTotal" => $shiptotal)->attr({"currencyID" => $currency})->type("") if $shiptotal;
		push @pd, SOAP::Data->name("HandlingTotal" => $handlingtotal)->attr({"currencyID" => $currency})->type("") if $handlingtotal;
		push @pd, SOAP::Data->name("InvoiceID" => $invoiceID)->type("") if length $invoiceID;
		push @pd, SOAP::Data->name("NotifyURL" => $notifyURL)->type("") if $notifyURL;
		push @pd, SOAP::Data->name("Custom" => $custom)->type("") if $custom;
#		push @pd, SOAP::Data->name("TransactionID" => $order_id)->type(""); # ###
		push @pd, $shiptoaddress if length $addressOverride;
		push @pd, @pditems unless $itemised_basket_off == '1';

	my $paymentDetails = (
	                SOAP::Data->name("PaymentDetails" =>
	                \SOAP::Data->value(
					@pd,
					)
				  )->type(""),
				);

	  push @setreq, $paymentDetails;
	  push @setreq, SOAP::Data->name("BrandName" => $brandName)->type("") if ($brandName and !$setrpbillagreement);
#::logDebug("PP".__LINE__.": ppdiscnote=$::Values->{pp_discount_note}");
		my $note_to_buyer = $::Values->{'pp_note_to_buyer'};
		   $note_to_buyer =~ s|\<.*\>||g;
		   $note_to_buyer .= " *** Discounts and coupons will be shown and applied before final payment" if  $::Values->{'pp_discount_note'};
		my $note  = (
	                SOAP::Data->name("NoteToBuyer" => $note_to_buyer)->type(""),
	                );
		$::Values->{'pp_discount_note'} = '';

	  push @setreq, $note; # ### 

							
	my ($bt,$rpdesc,$rpAgreementAmount,$rpStartDate);						

# rpStartDate > dateTime
	my @maxrpamt;
	my @setrpbill;
	my $cntr = '0';

#print "PP".__LINE__.": setreq=".::uneval(@setreq);

# Destroy the token here at the start of a new request, rather than after a 'dorequest' has completed,
# as Paypal use it to reject duplicate payments resulting from clicking the final 'pay' button more
# than once.
  
   undef $result{'Token'};

		$request = SOAP::Data->name("SetExpressCheckoutRequest" =>
				\SOAP::Data->value(
				 SOAP::Data->name("Version" => $version)->attr({ xmlns => "urn:ebay:apis:eBLBaseComponents" }),
				 SOAP::Data->name("SetExpressCheckoutRequestDetails" =>
				 \SOAP::Data->value(@setreq
				       )
				     ) ->attr({ xmlns => "urn:ebay:apis:eBLBaseComponents" }),
			       )
			     );

 	    $method = SOAP::Data->name('SetExpressCheckoutReq')->attr({xmlns=>$xmlns});
	    $response = $service->call($header, $method => $request);
	    %result = %{$response->valueof('//SetExpressCheckoutResponse')};
		$::Scratch->{'token'} = $result{'Token'};
 
   if (!$result{'Token'}) {
    if ($result{'Ack'} eq 'Failure') {
		  $::Session->{'errors'}{'PaypalExpress'} = $result{'Errors'}{'LongMessage'}  if ($result{'Errors'} !~ /ARRAY/);
			for my $i (0 .. 3) {
			  $::Session->{'errors'}{'PaypalExpress'} .= " $result{'Errors'}[$i]{'LongMessage'}"  if ($result{'Errors'} =~ /ARRAY/);
					}
			 }
    else {
       my $accepted = uc($::Variable->{CREDIT_CARDS_ACCEPTED});
       $::Session->{'errors'}{'PaypalExpress'} = errmsg("Paypal is currently unavailable - please use our secure payment system instead. We accept $accepted cards");
             }
	   return $Tag->deliver({ location => $checkouturl }) 
      }

#::logDebug("PP".__LINE__.": sandbox=$sandbox; host=$host");
# Now go off to Paypal
  my $redirecturl = "https://www."."$sandbox"."paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=$result{Token}";

return $Tag->deliver({ location => $redirecturl }); 

   }


#--------------------------------------------------------------------------------------------------
### Create a GET request and method, and read response
#
 elsif ($pprequest eq 'getrequest') {
	    $request = SOAP::Data->name("GetExpressCheckoutDetailsRequest" =>
			 \SOAP::Data->value(
		 	  SOAP::Data->name("Version" => $version)->type("xs:string"),
		         SOAP::Data->name("Token" => $::Scratch->{'token'})->type("xs:string")
			 )
		   ) ->attr({xmlns=>"urn:ebay:apis:eBLBaseComponents"});
	     $method = SOAP::Data->name('GetExpressCheckoutDetailsReq')->attr({xmlns => $xmlns});
	     $response = $service->call($header, $method => $request);
		 %result = %{$response->valueof('//GetExpressCheckoutDetailsResponse')};
#::logDebug("PP".__LINE__.": Get Ack=$result{Ack}");

# populate the billing address rather than shipping address when the basket is being shipped to
# another address, eg it is a wish list.
	  if (($result{'Ack'} eq "Success") and ($::Values->{'pp_use_billing_address'} == 1)) {
		$::Values->{'b_phone_day'}      = $result{'GetExpressCheckoutDetailsResponseDetails'}{'ContactPhone'};
		$::Values->{'email'}            = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Payer'};
		$::Values->{'payerid'}          = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerID'};
		$::Values->{'payerstatus'}      = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerStatus'};
		$::Values->{'payerbusiness'}    = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerBusiness'};
	    $::Values->{'salutation'}       = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerName'}{'Salutation'};
	    $::Values->{'b_fname'}          = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerName'}{'FirstName'};
	    $::Values->{'mname'}            = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerName'}{'MiddleName'};
	    $::Values->{'b_lname'}          = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerName'}{'LastName'};
	    $::Values->{'suffix'}           = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerName'}{'Suffix'};
	    $::Values->{'address_status'}   = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'AddressStatus'};
	    $::Values->{'b_name'}           = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerName'}{'PayerName'};
	    $::Values->{'b_address1'}       = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'Street1'};
	    $::Values->{'b_address2'}       = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'Street2'};
	    $::Values->{'b_city'}           = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'CityName'};
	    $::Values->{'b_state'}          = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'StateOrProvince'};
	    $::Values->{'b_zip'}            = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'PostalCode'};
	    $::Values->{'b_country'}        = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'Country'};
	    $::Values->{'countryname'}      = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'CountryName'};
	              }

	  elsif ($result{'Ack'} eq "Success") {
	    $::Values->{'phone_day'}      = $result{'GetExpressCheckoutDetailsResponseDetails'}{'ContactPhone'} || $::Values->{phone_day} || $::Values->{phone_night};
		$::Values->{'payerid'}        = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerID'};
		$::Values->{'payerstatus'}    = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerStatus'};
		$::Values->{'payerbusiness'}  = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerBusiness'};
	    $::Values->{'salutation'}     = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerName'}{'Salutation'};
	    $::Values->{'suffix'}         = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerName'}{'Suffix'};
	    $::Values->{'address_status'} = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'AddressStatus'};
	  if ($addressOverride != '1') {
		$::Values->{'email'}          = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Payer'};
	    $::Values->{'fname'}          = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerName'}{'FirstName'};
	    $::Values->{'mname'}          = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerName'}{'MiddleName'};
	    $::Values->{'lname'}          = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'PayerName'}{'LastName'};
	    $::Values->{'name'}           = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'Name'};
	    $::Values->{'address1'}       = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'Street1'};
	    $::Values->{'address2'}       = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'Street2'};
	    $::Values->{'city'}           = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'CityName'};
	    $::Values->{'state'}          = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'StateOrProvince'};
	    $::Values->{'zip'}            = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'PostalCode'};
	    $::Values->{'countryname'}    = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'CountryName'};
		$::Values->{'country'}        = $result{'GetExpressCheckoutDetailsResponseDetails'}{'PayerInfo'}{'Address'}{'Country'};
	              }
		   }
		   
		$::Values->{'company'} = $::Values->{'b_company'} = $::Values->{'payerbusiness'};
		$::Values->{'giropaytrue'} = $result{'GetExpressCheckoutDetailsResponseDetails'}{'RedirectRequired'};

#::logDebug("PP".__LINE__.": on=$::Values->{mv_order_number}");
		$invoiceID = $::Session->{'mv_order_number'} = $::Values->{'mv_order_number'} = $result{'Custom'} unless ($::Values->{'mv_order_number'} || $invoiceID);

# If shipping address and name are chosen at Paypal to be different to the billing address/name, then {name} contains 		
# the shipping name but {fname} and {lname} still contain the billing names.
### In this case the returned 'name' may be a company name as it turns out, so what should we do?
   if (($::Values->{'fname'} !~ /$::Values->{'name'}/) and ($::Values->{'name'} =~ /\s/)) {
       $::Values->{'name'} =~ /(\S*)\s+(.*)/;
       $::Values->{'fname'} = $1;
       $::Values->{'lname'} = $2;
    }
		
		  $::Session->{'errors'}{'PaypalExpress'} = $result{'Errors'}{'LongMessage'}  if ($result{'Errors'} !~ /ARRAY/);
			for my $i (0 .. 3) {
			  $::Session->{'errors'}{'PaypalExpress'} .= " $result{'Errors'}[$i]{'LongMessage'}"  if ($result{'Errors'} =~ /ARRAY/);
			}
   
       $country = $::Values->{'country'} || $::Values->{'b_country'};
       $state = $::Values->{'state'} || $::Values->{'b_state'};
       $state =~ s/\.\s*//g; # yet another variation for Canadian Provinces includes periods, eg B.C. (waiting for B. C.)

# Remap Canadian provinces rather than lookup the db, as some Paypal names are incomplete wrt the official names. 
# It seems that some PP accounts, possibly older ones, send the 2 letter abbreviation rather than the full name.
	if ($country eq 'CA') {		
		$state = 'AB' if ($state =~ /Alberta|^AB$/i);
		$state = 'BC' if ($state =~ /British Columbia|^BC$/i);
		$state = 'MB' if ($state =~ /Manitoba|^MB$/i);
		$state = 'NB' if ($state =~ /New Brunswick|^NB$/i);
		$state = 'NL' if ($state =~ /Newfoundland|^NL$/i);
		$state = 'NS' if ($state =~ /Nova Scotia|^NS$/i);
		$state = 'NT' if ($state =~ /Northwest Terr|^NT$/i);
		$state = 'NU' if ($state =~ /Nunavut|^NU/i);
		$state = 'ON' if ($state =~ /Ontario|^ON$/i);
		$state = 'PE' if ($state =~ /Prince Edward|^PE$/i);
		$state = 'QC' if ($state =~ /Quebec|^QC$/i);
		$state = 'SK' if ($state =~ /Saskatchewan|^SK$/i);
		$state = 'YT' if ($state =~ /Yukon|^YT$/i);
	}
        
        $::Values->{'b_state'} = $state if ($::Values->{'pp_use_billing_address'} == 1);
        $::Values->{'state'} = $state;
  
  }

#------------------------------------------------------------------------------------------------
### Create a Do request and method, and read response. Not used for Giropay
#
 elsif ($pprequest =~ /dorequest|modifyrp/) {
     #  $currency = 'EUR'; # set to currency different to that started with to force failure for testing
#::logDebug("PP".__LINE__.":invID=$invoiceID; on=$::Values->{mv_order_number}; total=$amount, itemtotal=$itemTotal, shiptot=$shipTotal,handTot=$handlingTotal,taxtot=$taxTotal");
			$invoiceID = ($::Values->{'mv_order_number'} || $::Values->{'order_number'}) unless $invoiceID;

	   my @pd  = (
				     SOAP::Data->name("OrderTotal" => $amount )->attr({"currencyID" => $currency})->type(""),
				     SOAP::Data->name("ItemTotal" => $itemTotal )->attr({"currencyID" => $currency})->type(""),
				     SOAP::Data->name("ShippingTotal" => $shipTotal )->attr({"currencyID" => $currency})->type(""),
				     SOAP::Data->name("HandlingTotal" => $handlingTotal )->attr({"currencyID" => $currency})->type(""),
				     SOAP::Data->name("TaxTotal" => $taxTotal )->attr({"currencyID" => $currency})->type(""),
				     SOAP::Data->name("InvoiceID" => $invoiceID )->type(""),
                     );

        my @sta  = (
                    SOAP::Data->name("ShipToAddress" =>
                    \SOAP::Data->value(
                     SOAP::Data->name("Name" => $name)->type("xs:string"),
                     SOAP::Data->name("Street1" => $address1)->type("xs:string"),
                     SOAP::Data->name("Street2" => $address2)->type("xs:string"),
                     SOAP::Data->name("CityName" => $city)->type("xs:string"),
                     SOAP::Data->name("StateOrProvince" => $state)->type("xs:string"),
                     SOAP::Data->name("PostalCode" => $zip)->type("xs:string"),
                     SOAP::Data->name("Country" => $country)->type("xs:string")
                         )
                       )
                     );

		  my ($item,$itm,@pdi,$pdiamount,$pditax);
# ### FIXME what is the point of sending item details here???? 
		if (($itemTotal > '0') and ($taxTotal > '0')) {
		  foreach  $item (@{$::Carts->{'main'}}) {
			  $itm = {
					  number => $item->{'code'},
					  quantity => $item->{'quantity'},
					  description => Vend::Data::item_description($item),
					  amount => Vend::Data::item_price($item),
					  comment => Vend::Data::item_field($item, 'comment'),
					  tax => exists $item->{'tax'} ? $item->{'tax'} : (Vend::Data::item_price($item)/$itemTotal * $taxTotal),
					  rpAmount => Vend::Data::item_field($item, 'rpamount'),
					  };
  
			  $pdiamount = sprintf '%.02f', $itm->{'amount'};
			  $pditax = sprintf '%.02f', $itm->{'tax'};

		my $pdi  = (
	                SOAP::Data->name("PaymentDetailsItem" =>
	                \SOAP::Data->value(
	                 SOAP::Data->name("Name" => $itm->{'description'})->type("xs:string"),
	                 SOAP::Data->name("Amount" => $pdiamount)->attr({"currencyID" => $currency})->type("xs:string"),
	                 SOAP::Data->name("Number" => $itm->{'number'})->type("xs:string"),
	                 SOAP::Data->name("Quantity" => $itm->{'quantity'})->type("xs:string"),
	                 SOAP::Data->name("Tax" => $pditax)->type("xs:string")
	                    )
	                  )->type("ebl:PaymentDetailsItemType")
	                );
	  push @pdi, $pdi unless $itm->{'rpAmount'} > '0';
	  }
    }
#----------------------------------

	my ($shipAddress, $billAddress, $payerInfo, @schedule, $nonrp);
	my $cntr = '0';
	my $rpamount_field = 'rpamount_' . lc($currency) || 'rpamount';
	my $rptrialamount_field = 'rptrialamount_' . lc($currency) || 'rptrialamount';
	my $rpdeposit_field = 'rpdeposit_' . lc($currency) || 'rpdeposit';

	foreach  $item (@{$::Carts->{'main'}}) {
	    $itm = {
				rpamount_field => Vend::Data::item_field($item, $rpamount_field),
				rpamount => Vend::Data::item_field($item, 'rpamount'),
	    		amount => Vend::Data::item_price($item),
				description => Vend::Data::item_field($item, 'description'),
				};


   $basket .= <<EOB;
   Item = $itm->{code}, "$itm->{rpDescription}"; Price = $itm->{price}; Qty = $itm->{quantity}; Subtotal = $itm->{subtotal} 
EOB

	  my ($dorecurringbilling, $cntr);
	  my $rpamount = $itm->{'rpamount_field'} || $itm->{'rpamount'};
		 $nonrp = '1' if (! $rpamount); # only run Do request if have standard purchase as well
	  if ($rpamount) {
#		$cntr++;
print "PP".__LINE__.": cntr=$cntr; initamount=$itm->{initAmount}; rpAmount=$itm->{rpAmount}; trialAmount=$itm->{trialAmount}\n";	
            $dorecurringbilling = (
					   SOAP::Data->name("BillingAgreementDetails" =>
					   \SOAP::Data->value(
					    SOAP::Data->name("BillingType" => 'RecurringPayments')->type(""),
						SOAP::Data->name("BillingAgreementDescription" => $itm->{'description'})->type(""),
						      )
						    )->type("ns:BillingAgreementDetailsType"),
						);
		$cntr++;
		push @pd, $dorecurringbilling;
	  }
					   
	};	

		push @pd, SOAP::Data->name("Custom" => $custom )->type("xs:string") if $custom;
		push @pd, SOAP::Data->name("NotifyURL" => $notifyURL )->type("xs:string") if $notifyURL;
		push @pd, @sta if $addressOverride  == '1';
		push @pd, @pdi if $paymentDetailsItem == '1';# and ($itemTotal > '0'));

	my $pd = (      SOAP::Data->name("PaymentDetails" =>
			         \SOAP::Data->value( @pd
				     ),
			       )->type(""),
				);

	my @doreq = (	 SOAP::Data->name("Token" => $::Scratch->{'token'})->type("xs:string"),
			         SOAP::Data->name("PaymentAction" => $paymentAction)->type(""),
			         SOAP::Data->name("PayerID" => $::Values->{'payerid'} )->type("xs:string"),
				);
# ###		push @doreq, SOAP::Data->name("ReturnFMFDetails" => '1' )->type("xs:boolean") if $returnFMFdetails == '1'; # ### crashes
# ###		push @doreq, SOAP::Data->name("GiftMessage" => $giftMessage)->type("xs:string") if $giftMessage;
		push @doreq, SOAP::Data->name("GiftReceiptEnable" => $giftReceiptEnable)->type("xs:string") if $giftReceiptEnable; # true | false
		push @doreq, SOAP::Data->name("GiftWrapName" => $giftWrapName)->type("xs:string") if $giftWrapName; # 25 chars
		push @doreq, SOAP::Data->name("GiftWrapAmount" => $giftWrapAmount)->attr({"currencyID" => $currency})->type("ebl:BasicAmountType") if $giftWrapAmount;
		push @doreq, SOAP::Data->name("ButtonSource" => $buttonSource )->type("xs:string") if $buttonSource;
		push @doreq, SOAP::Data->name("SoftDescriptor" => $softDescriptor)->type('') if $softDescriptor;

		push @doreq, $pd;

	    $request = SOAP::Data->name("DoExpressCheckoutPaymentRequest" =>
			       \SOAP::Data->value(
			        SOAP::Data->name("Version" => $version)->attr({xmlns=>"urn:ebay:apis:eBLBaseComponents"})->type("xs:string"),
			        SOAP::Data->name("DoExpressCheckoutPaymentRequestDetails" =>
			        \SOAP::Data->value(
					@doreq,
			     ),
			   )->attr({xmlns=>"urn:ebay:apis:eBLBaseComponents"}),
			 ),
		   );

	if (($nonrp == '1') and ($pprequest ne 'modifyrp')) {
		undef $nonrp;

	    $method = SOAP::Data->name('DoExpressCheckoutPaymentReq')->attr({xmlns => $xmlns});
	    $response = $service->call($header, $method => $request);
	    %result = %{$response->valueof('//DoExpressCheckoutPaymentResponse')};
#::logDebug("PP".__LINE__.": nonRP=$nonrp; Do Ack=$result{Ack}; ppreq=$pprequest");
	 my ($rpAmount, $rpPeriod, $rpFrequency, $totalBillingCycles, $trialPeriod, $trialFrequency, $trialAmount, $trialTotalBillingCycles, @setrpprofile);
  
	  if ($result{'Ack'} eq "Success") {
	    $Session->{'payment_result'}{'Status'} = 'Success' unless (@setrpprofile);
	    $result{'TransactionID'}       = $result{'DoExpressCheckoutPaymentResponseDetails'}{'PaymentInfo'}{'TransactionID'};
	    $result{'PaymentStatus'}       = $result{'DoExpressCheckoutPaymentResponseDetails'}{'PaymentInfo'}{'PaymentStatus'};
	    $result{'TransactionType'}     = $result{'DoExpressCheckoutPaymentResponseDetails'}{'PaymentInfo'}{'TransactionType'};
	    $result{'PaymentDate'}         = $result{'DoExpressCheckoutPaymentResponseDetails'}{'PaymentInfo'}{'PaymentDate'};
	    $result{'ParentTransactionID'} = $result{'DoExpressCheckoutPaymentResponseDetails'}{'PaymentInfo'}{'ParentTransactionID'};
	    $result{'PaymentType'}         = $result{'DoExpressCheckoutPaymentResponseDetails'}{'PaymentInfo'}{'PaymentType'};
	    $result{'PendingReason'}       = $result{'DoExpressCheckoutPaymentResponseDetails'}{'PaymentInfo'}{'PendingReason'};
	    $result{'PaymentDate'}         = $result{'DoExpressCheckoutPaymentResponseDetails'}{'PaymentInfo'}{'PaymentDate'};
	    $result{'ReasonCode'}          = $result{'DoExpressCheckoutPaymentResponseDetails'}{'PaymentInfo'}{'ReasonCode'};
	    $result{'FeeAmount'}           = $result{'DoExpressCheckoutPaymentResponseDetails'}{'PaymentInfo'}{'FeeAmount'};
	    $result{'ExchangeRate'}        = $result{'DoExpressCheckoutPaymentResponseDetails'}{'PaymentInfo'}{'ExchangeRate'};
		$result{'giropaytrue'}         = $result{'DoExpressCheckoutPaymentResponseDetails'}{'RedirectRequired'};

			    }
 	  else  {
	  		  $::Session->{'errors'}{'PaypalExpress'} = $result{'Errors'}{'LongMessage'}  if ($result{'Errors'} !~ /ARRAY/);
			  for my $i (0 .. 3) {
				$::Session->{'errors'}{'PaypalExpress'} .= " $result{'Errors'}[$i]{'LongMessage'}"  if ($result{'Errors'} =~ /ARRAY/);
			  }
	  }
#::logDebug("PP".__LINE__.": Doreq result=".::uneval(\%result));

	}

	my $cntr = '0';

#
# Finished with DoRequest for normal purchase, now for RecurringPayments profiles
# Need to run one complete request/response cycle per Profile
#
	foreach  $item (@{$::Carts->{'main'}}) {
	my (@activation,@trialperiod,$rpprofile,$rprequest,@profiledetails,@scheduledetails,@end,$cardToken);

	    $itm = {
				rpDescription => Vend::Data::item_field($item, 'description'),
				rpAutoBillOutstandingAmount => Vend::Data::item_field($item, 'rpautobillarrears'),
				rpMaxFailedPayments => Vend::Data::item_field($item, 'rpmaxfailedpayments'),
				rpStartDate => Vend::Data::item_field($item, 'rpstartdate'),
				rpAmount_field => Vend::Data::item_field($item, $rpamount_field),
				rpAmount => Vend::Data::item_field($item, 'rpamount'),
				rpShippingAmount => Vend::Data::item_field($item, 'rpshippingamount'),
				rpTaxAmount => Vend::Data::item_field($item, 'rptaxamount'),
				rpPeriod => Vend::Data::item_field($item, 'rpperiod'),
				rpFrequency => Vend::Data::item_field($item, 'rpfrequency'),
				rpTotalCycles => Vend::Data::item_field($item, 'rptotalcycles'),
				trialPeriod => Vend::Data::item_field($item, 'rptrialperiod'),
				trialFrequency => Vend::Data::item_field($item, 'rptrialfrequency'),
				trialAmount => Vend::Data::item_field($item, $rptrialamount_field),
				trialShippingAmount => Vend::Data::item_field($item, 'rptrialshippingamount'),
				trialTaxAmount => Vend::Data::item_field($item, 'rptrialtaxamount'),
				trialTotalCycles => Vend::Data::item_field($item, 'rptrialtotalcycles'),
				initAmount => Vend::Data::item_field($item, $rpdeposit_field),
				initAmountFailedAction => Vend::Data::item_field($item, 'rpdepositfailedaction'),
				};

	my $rpStartDate = $itm->{'rpStartDate'} || $Tag->time({ body => "%Y-%m-%d" });
	   $rpStartDate .= "T00:00:00";
	my $rpPeriod = $::Values->{'rpperiod'} || $itm->{'rpPeriod'};
	   $rpPeriod = ucfirst(lc($rpPeriod)); # 'type mismatch' error if case not right ...
	   $rpPeriod = 'SemiMonth' if $rpPeriod =~ /semimonth/i;
	my $trialPeriod = $::Values->{'trialperiod'} || $itm->{'trialPeriod'};
	   $trialPeriod = ucfirst(lc($trialPeriod)); 
	   $trialPeriod = 'SemiMonth' if $trialPeriod =~ /semimonth/i;
	my $rpAmount = $::Values->{'repayamount'} || $itm->{'rpAmount_field'} || $itm->{'rpAmount'};
	   $rpAmount = sprintf '%.2f', $rpAmount;
	my $initamountfailedaction = $::Values->{'initamountfailedaction'} || $itm->{'initAmountFailedAction'};
	   $initamountfailedaction = 'ContinueOnFailure' if $initamountfailedaction =~ /continueonfailure/i;
	   $initamountfailedaction = 'CancelOnFailure' if $initamountfailedaction =~ /cancelonfailure/i;

#-- now for the CreateRecurringPayments request ---------------------------------------
#
	if ($rpAmount > '0') {
	    $rpAmount = sprintf '%.02f', $rpAmount;

	if ($cntr > '9') {
	  $::Session->{'errors'}{'Paypal'} = "Paypal will not accept more than ten subscriptions in one order - please remove some and purchase them in
	  a second order";
	  return();
	};
		$cntr++;

		my $rpref = $invoiceID . "-sub" . $cntr if charge_param('setordernumber');
#::logDebug("PP".__LINE__.": invID=$invoiceID; profRef=$::Values->{'rpprofilereference'}; cnt=$cntr; shipAddress1=$itm->{'shipAddress1'};  rpFreq=$itm->{rpFrequency}; rpAmount=$itm->{rpAmount}; billP=$itm->{rpPeriod}; start=$rpStartDate");	
		my $rpStartDate = $::Values->{'rpstartdate'} || $itm->{'rpStartDate'} || strftime('%Y-%m-%dT%H:%M:%S',localtime); ##today; # FIXME 'valid GMT format', required: "yyyy-mm-dd hh:mm:ss GMT"
# startdate either proper date format if taken from db or terminal, or may be period hence,
# eg '1 week', '3 days', '2 months'. Eg, deposit (initAmount) now plus payments starting
# in 1 month. 
		if ($rpStartDate =~ /\d+ \w+/){
		  my ($adder, $period) = split/ /, $rpStartDate ;  
			  $adder *= '7' if $period =~ /week/i;

		  my ($year,$month,$day) = Add_Delta_YMD(Today(),'0',"+$adder",'0') if $period =~ /month/i;
			 ($year,$month,$day) = Add_Delta_YMD(Today(),'0','0',"+$adder") if $period =~ /day/i;
			  $month = sprintf '%02d', $month;
			  $day = sprintf '%02d', $day;
			 $rpStartDate = "$year-$month-$day" . "T00:00:00Z"; 
		}
		   $rpStartDate .= 'T00:00:00Z' if $rpStartDate !~ /T/;

		my $profileReference = $::Values->{'rpprofilereference'} || $rpref;
		   $::Values->{'rpprofilereference'} = '';
#::logDebug("PP".__LINE__.": rcStart=$rpStartDate; profRef=$profileReference");



		$shipAddress = (   SOAP::Data->name('SubscriberShippingAddress' =>
						   \SOAP::Data->value(
							SOAP::Data->name('Name' => "$::Values->{'fname'} $::Values->{'lname'}")->type(''),
							SOAP::Data->name('Street1' => $::Values->{'address1'})->type(''),
							SOAP::Data->name('Street2' => $::Values->{'address2'})->type(''),
							SOAP::Data->name('CityName' => $::Values->{'city'})->type(''),
							SOAP::Data->name('StateOrProvince' => $::Values->{'state'})->type(''),
							SOAP::Data->name('PostalCode' => $::Values->{'zip'})->type(''),
							SOAP::Data->name('Country' => $::Values->{'country'})->type(''),
							),
						   ),
						) if $::Values->{'address18'};

	  my $payment = (
						   SOAP::Data->name('PaymentPeriod' => 
							\SOAP::Data->value(
 						     SOAP::Data->name('BillingPeriod' => $rpPeriod)->type(''),
							 SOAP::Data->name('BillingFrequency' => $::Values->{'rpfrequency'} || $itm->{'rpFrequency'})->type(''), 
							 SOAP::Data->name('TotalBillingCycles' => $::Values->{'rptotalcycles'} || $itm->{'rpTotalCycles'})->type(''),
							 SOAP::Data->name('Amount' => $rpAmount)->attr({'currencyID' => $currency})->type(''),
							 SOAP::Data->name('ShippingAmount' => $::Values->{'rpshippingamount'} || $itm->{'rpShippingAmount'})->attr({'currencyID' => $currency})->type(''),
							 SOAP::Data->name('TaxAmount' => $::Values->{'rptaxamount'} || $itm->{'rpTaxAmount'})->attr({'currencyID' => $currency})->type(''),
							 ),
						   ),
						);

	  my $activation = (	
							SOAP::Data->name('ActivationDetails' => 
							\SOAP::Data->value(
 						     SOAP::Data->name('InitialAmount' => $::Values->{'initamount'} || $itm->{'initAmount'})->attr({'currencyID' => $currency})->type(''),
							 SOAP::Data->name('FailedInitialAmountAction' => $initamountfailedaction)->type(''), 
								),
							  ),
						) if ($::Values->{'initamount'} || $itm->{'initAmount'});

	  my $trial =   ( 
							SOAP::Data->name('TrialPeriod' => 
							\SOAP::Data->value(
 						     SOAP::Data->name('BillingPeriod' => $trialPeriod)->type(''),
							 SOAP::Data->name('BillingFrequency' => $::Values->{'trialfrequency'} || $itm->{'trialFrequency'})->type(''), 
							 SOAP::Data->name('Amount' => $::Values->{'trialamount'} || $itm->{'trialAmount'})->attr({'currencyID' => $currency})->type(''),
							 SOAP::Data->name('ShippingAmount' => $::Values->{'trialshippingamount'} || $itm->{'trialShippingAmount'})->attr({'currencyID' => $currency})->type(''),
							 SOAP::Data->name('TaxAmount' => $::Values->{'trialtaxamount'} || $itm->{'trialTaxAmount'})->attr({'currencyID' => $currency})->type(''),
							 SOAP::Data->name('TotalBillingCycles' => $::Values->{'trialtotalcycles'} || $itm->{'trialTotalCycles'})->type(''),
							  ),
							),
						  ) if ($::Values->{'trialamount'} || $itm->{'trialAmount'});

		push @scheduledetails, $payment;
		push @scheduledetails, $activation if length $activation;
		push @scheduledetails, $trial if length $trial;
		push @profiledetails, SOAP::Data->name("BillingStartDate" => $rpStartDate)->type("");
		push @profiledetails, SOAP::Data->name("ProfileReference" => $profileReference)->type("");
		push @profiledetails, $shipAddress if length $shipAddress;
		
		$rprequest = (  
					  SOAP::Data->name("CreateRecurringPaymentsProfileRequest" =>
					  \SOAP::Data->value(
					   SOAP::Data->name("Version" => $version)->attr({ xmlns => "urn:ebay:apis:eBLBaseComponents" })->type(''),
					   SOAP::Data->name("CreateRecurringPaymentsProfileRequestDetails" =>
					   \SOAP::Data->value(
						SOAP::Data->name("Token" => $::Scratch->{"token"})->type("xs:string"),
						SOAP::Data->name("RecurringPaymentsProfileDetails" =>
						\SOAP::Data->value(
						  @profiledetails,
						  ),
						),
						SOAP::Data->name('ScheduleDetails' =>
						\SOAP::Data->value(
						SOAP::Data->name('Description' => $::Values->{'rpdescription'} || $itm->{'rpDescription'})->type(''),
						@scheduledetails,
						SOAP::Data->name('MaxFailedPayments' => $::Values->{'rpmaxfailedpayments'} || $itm->{'rpMaxFailedPayments'} || '1')->type(''),
						SOAP::Data->name('AutoBillOutstandingAmount' => $::Values->{'rpautobillarrears'} || $itm->{'rpAutoBillOutstandingAmount'} || 'NoAutoBill')->type(''),
						  ),
						),
					  ),
					)->attr({ xmlns => "urn:ebay:apis:eBLBaseComponents" }),
				  ),
				),
			);

#::logDebug("PP".__LINE__.": dorp=".::uneval($rprequest));

# send separate query to Paypal for each RP profile
		$method = SOAP::Data->name('CreateRecurringPaymentsProfileReq')->attr({ xmlns => $xmlns });
	    $response = $service->call($header, $method => $rprequest);
no strict 'refs';
	  my $error = $response->valueof('//faultstring');
use strict;
	    %result = %{$response->valueof('//CreateRecurringPaymentsProfileResponse')};
#::logDebug("PP".__LINE__.": CreateRecPayresult=".::uneval(\%result));

		 $::Session->{'errors'}{'PaypalExpress'} .= $error;
		 $::Session->{'errors'}{'PaypalExpress'} .= $result{'Errors'}{'LongMessage'}  if ($result{'Errors'} !~ /ARRAY/);
			for my $i (0 .. 3) {
			  $::Session->{'errors'}{'PaypalExpress'} .= " $result{'Errors'}[$i]{'LongMessage'}"  if ($result{'Errors'} =~ /ARRAY/);
			}

	  if ($result{'Ack'} eq "Success") {
		$db = dbref('transactions');
		$dbh = $db->dbh() or die errmsg("cannot get handle for tbl 'transactions'");
	    $::Session->{'payment_result'}{'Status'} = 'Success';
		$::Scratch->{'charge_succeed'} = '1';
        $result{'order-id'} = $order_id || $opt->{'order_id'};
	    $result{'CorrelationID'} = $result{'CreateRecurringPaymentsProfileResponse'}{'CorrelationID'};

	  my ($rpshowsubtotal, $rpshowshipping, $rpshowtax, $rpshowtotal);

			$result{'ProfileID'}     = $result{'CreateRecurringPaymentsProfileResponseDetails'}{'ProfileID'};
			$result{'ProfileStatus'} = $result{'CreateRecurringPaymentsProfileResponseDetails'}{'ProfileStatus'};
			$result{'TransactionID'} = $result{'CreateRecurringPaymentsProfileResponseDetails'}{'TransactionID'};
			my $profilestatus = $result{'ProfileStatus'};
			   $profilestatus =~ s/Profile//;

# In log_transaction find ProfileID from ProfileReference, run 'getrpdetails' and put into orderline tbl
# pages/query/order_detail has new col for Subs, link to popup which runs 'getrpdetails' and
# displays info to customer from scratch values

	my $sql = "INSERT transactions SET code='$profileReference',order_id='$result{ProfileID}',status='$profilestatus'";

				$sth = $dbh->prepare($sql);
				$sth->execute() or die $sth->errstr;
#::logDebug("PP".__LINE__.": Ack=$result{'Ack'}; result=".::uneval(\%result));

		  } # if Ack eq success

		} # if item rpAmount

	  } # foreach item in cart 

	}

#---------------------------------------------------------------------------------------
# Manage RecurringPayments: to cancel, suspend or reactivate. Use 'modify' for other ops
#
  elsif ($pprequest =~ /managerp/) {
 
	my ($x,$action) = split(/_/, $pprequest);
	my $status = 'Suspended' if $action eq 'suspend';
	   $status = 'Cancelled' if $action eq 'cancel';
	   $status = 'Active' if $action eq 'reactivate';
	   $action = ucfirst(lc($action));

		my $request  = ( 
					  SOAP::Data->name('ManageRecurringPaymentsProfileStatusRequest' =>
					  \SOAP::Data->value(
					   SOAP::Data->name('Version' => $version)->attr({xmlns => 'urn:ebay:apis:eBLBaseComponents'})->type('xs:string'),
					   SOAP::Data->name('ManageRecurringPaymentsProfileStatusRequestDetails' =>
					   \SOAP::Data->value(
						 SOAP::Data->name('ProfileID' => $::Values->{'rpprofileid'})->type('xs:string'),
						 SOAP::Data->name('Action' => $action)->type(''),
						 SOAP::Data->name('Note' => $::Values->{'vtmessage'})->type('xs:string'),
						),
					 )->attr({xmlns => 'urn:ebay:apis:eBLBaseComponents'}),
				  ),
				),
			  );

	    $method = SOAP::Data->name('ManageRecurringPaymentsProfileStatusReq')->attr({xmlns=>$xmlns});
	    $response = $service->call($header, $method => $request);
	    %result = %{$response->valueof('//ManageRecurringPaymentsProfileStatusResponse')};
	  
		if ($result{'Ack'} eq 'Success') {
	      $db  = dbref('transactions') or die errmsg("cannot open transactions table");
	      $dbh = $db->dbh() or die errmsg("cannot get handle for tbl 'transactions'");
		  $sth = $dbh->prepare("UPDATE transactions SET rpprofilestatus='$status',txtype='PP:RecPay-$status',status='PP:RecPay-$status' WHERE rpprofileid='$::Values->{rpprofileid}'");
          $sth->execute() or die $sth->errstr;
		}
#::logDebug("PP".__LINE__.": action=$action; result=".::uneval(%result));
		return(%result);

  }

#--------------------------------------------------------------------------------------------
# Get full RecurringPayments details and put into scratch space
#
  elsif ($pprequest =~ /getrpdetails/) {
	my ($x,$update) = split /_/, $pprequest if $pprequest =~ /_/;
	$::Session->{'rpupdate'} = '1' if $update;
	getrpdetails();
	return();
  }

#-----------------------------------------------------------------------------------------
#  RecurringPayments: bill arrears
#
  elsif ($pprequest eq 'billrparrears') {

		  my $request  = ( 
					  SOAP::Data->name('BillOutstandingAmountRequest' =>
					  \SOAP::Data->value(
					   SOAP::Data->name('Version' => $version)->attr({xmlns => 'urn:ebay:apis:eBLBaseComponents'})->type('xs:string'),
					   SOAP::Data->name('BillOutstandingAmountRequestDetails' =>
					   \SOAP::Data->value(
						 SOAP::Data->name('ProfileID' => $::Values->{'rpprofileid'})->type(''),
						 SOAP::Data->name('Amount' => $amount)->attr({'currencyID' => $currency})->type(''),
						 SOAP::Data->name('Note' => $::Values->{'vtmessage'})->type(''),
						),
				     )->attr({xmlns => 'urn:ebay:apis:eBLBaseComponents'}),
				  ),
				),
			  );

	    $method = SOAP::Data->name('BillOutstandingAmountReq')->attr({ xmlns => $xmlns });
	    $response = $service->call($header, $method => $request);
no strict 'refs';
	  my $error = $response->valueof('//faultstring');
use strict;
	    %result = %{$response->valueof('//BillOutstandingAmountResponse')};
#::logDebug("PP".__LINE__.": result=".::uneval(%result));

		return(%result);

  }

#-------------------------------------------------------------------------------------------------
# REFUND transaction
#
 elsif ($pprequest =~ /refund/) {
	   my @refundreq = (
                    SOAP::Data->name("Version" => $version)->type("xs:string")->attr({xmlns => "urn:ebay:apis:eBLBaseComponents"}),
                    SOAP::Data->name("TransactionID" => $transactionID)->type("ebl:TransactionId"),
                    SOAP::Data->name("RefundType" => $refundType)->type(""),
                    SOAP::Data->name("Memo" => $memo)->type("xs:string"),
                     );

	  push @refundreq,  SOAP::Data->name("Amount" => $amount)->attr({"currencyID" => $currency})->type("cc:BasicAmountType")
					if $pprequest eq 'refund_partial';
                  
     $request = SOAP::Data->name("RefundTransactionRequest" =>
                \SOAP::Data->value( 
				  @refundreq
				  )
				)->type("ns:RefundTransactionRequestType");

	    $method = SOAP::Data->name('RefundTransactionReq')->attr({xmlns => $xmlns});
	    $response = $service->call($header, $method => $request);
	    %result = %{$response->valueof('//RefundTransactionResponse')};
	    	
	    	if ($result{'Ack'} eq "Success") {
	  		$::Session->{'payment_result'}{'Terminal'} = 'success';
	      	$::Session->{'payment_result'}{'RefundTransactionID'} = $result{'RefundTransactionResponse'}{'RefundTransctionID'};
#::logDebug("PP".__LINE__.": Refund result=".::uneval(%result));
			return %result;
	    		}
		}

#-------------------------------------------------------------------------------------------------
# MASSPAY transaction
#
 elsif ($pprequest eq 'masspay') {
	my ($receiver, $mpamount, $ref, $note, $mpi, @mp);
	my $emailsubject = $::Values->{'email_subject'} || 'Paypal payment';
    my $message = $::Values->{'vtmessage'};
#::logDebug("PP".__LINE__.": req=$pprequest; list=$message");

	if ($message) {
		$message =~ s/\r//g;
	foreach my $line (split /\n/, $message) {
#::logDebug("PP".__LINE__.": masspay line=$line");
		  ($receiver, $mpamount, $ref, $note) = split /","/, $line;
		  $receiver =~ s/^\"//;
		  $note =~ s/\"$// || ' ';
		  $mpamount = sprintf '%.02f', $mpamount;
		  $mpamount =~ s/^\D+//g;

#  need: receiver email/ID, amount, ref, note. Note can be empty but must be quoted
		if ($receiver =~ /\@/) {
		$receiverType = SOAP::Data->name("ReceiverEmail" => $receiver)->type("ebl:EmailAddressType");
			}
		else {
		$receiverType = SOAP::Data->name("ReceiverID" => $receiver)->type("xs:string");
		}
		 $mpi = (
                  SOAP::Data->name("MassPayItem" =>
                   \SOAP::Data->value(
                    $receiverType,
                    SOAP::Data->name("Amount" => $mpamount)->attr({ "currencyID" => $currency })->type("ebl:BasicAmountType"),
                    SOAP::Data->name("UniqueID" => $ref)->type("xs:string"),
                    SOAP::Data->name("Note" => $note)->type("xs:string")
                    )
                 ) ->type("ns:MassPayItemRequestType")
              );
		push @mp, $mpi;
			}
		  }

	$request = SOAP::Data->name("MassPayRequest" =>
			   \SOAP::Data->value(
                SOAP::Data->name("Version" => $version)->type("xs:string")->attr({ xmlns => "urn:ebay:apis:eBLBaseComponents" }),
			    SOAP::Data->name("EmailSubject" => $emailsubject)->type("xs:string"),
                @mp
                   )
                 ) ->type("ns:MassPayRequestType");

	    $method = SOAP::Data->name('MassPayReq')->attr({ xmlns => $xmlns });
	    $response = $service->call($header, $method => $request);
	    %result = %{$response->valueof('//MassPayResponse')};
	  	$::Session->{'payment_result'}{'Terminal'} = 'success' if $result{'Ack'} eq 'Success';
#::logDebug("PP".__LINE__.":response=$result{Ack},cID=$result{CorrelationID}");
# returns only Ack and CorrelationID on success
#::logDebug("PP".__LINE__.": MassPay result=".::uneval(%result));
		return %result;

      }

#---------------------------------------------------------------------------
# IPN
#
  elsif ($pprequest =~ /ipn/) {
 	my $page = ::http()->{'entity'};
	my $query = 'https://' . $ipnhost . '/cgi-bin/webscr?cmd=_notify-validate&' . $$page;
#::logDebug("PP".__LINE__.": url=$query"); 	

   my $ua = LWP::UserAgent->new;
   my $req = HTTP::Request->new('POST' => $query);
	  $req->content_type('text/url-encoded');
	  $req->content();
   my $res = $ua->request($req);
   my $respcode = $res->status_line;

	 if ($res->is_success) {
		  if ($res->content() eq 'VERIFIED') {
			  foreach my $line (split /\&/, $$page) {
				my ($key, $val) = (split /=/, $line);
				$result{$key} = $val;
#::logDebug("PP".__LINE__.": IPN result=".::uneval(%result));
				return %result;

			  }
			}
		  }
	  else {
	  }
#::logDebug("PP".__LINE__.": resp=$res->content()"); 	

	return();

  }

#-----------------------------------------------
# Get balance of accounts
#
  elsif ($pprequest =~ /getbalance/) {
	  my ($req, $account) = split (/_/, $pprequest) if $pprequest =~ /_/;
		  $account ||= 'Balance';
		  
	   my @balancereq = (
                    SOAP::Data->name("Version" => $version)->type("xs:string")->attr({xmlns => "urn:ebay:apis:eBLBaseComponents"}),
                    SOAP::Data->name("ReturnAllCurrencies" => '1')->type(""),
                     );

		$request = SOAP::Data->name("GetBalanceRequest" =>
					\SOAP::Data->value( 
					 @balancereq
					)
				  ) ->type("ns:GetBalanceRequestType");

	    $method = SOAP::Data->name('GetBalanceReq')->attr({xmlns => $xmlns});
	    $response = $service->call($header, $method => $request);
	    %result = %{$response->valueof('//GetBalanceResponse')};

		  $::Session->{'errors'}{'PaypalExpress'} = $result{'Errors'}{'LongMessage'}  if ($result{'Errors'} !~ /ARRAY/);
			for my $i (0 .. 3) {
			  $::Session->{'errors'}{'PaypalExpress'} .= " $result{'Errors'}[$i]{'LongMessage'}"  if ($result{'Errors'} =~ /ARRAY/);
			}
#::logDebug("PP".__LINE__.": GetBalance result=".::uneval(%result));

		$::Scratch->{'paypalbalance'} = "$account ";
		for my $x ($response->dataof('//BalanceHoldings')) {
			$::Scratch->{'paypalbalance'} .= " :: " . $x->{'_attr'}{'currencyID'} . $x->{'_value'}['0'];

		return;

		}
	    	
  }

#---------------------------------------------------------------------------------------
# DoReferenceTransaction, ie merchant-handled repeat of varying amounts at varying times
#
  elsif ($pprequest =~ /dorepeat/) {

  }

#--------------------------------------------------------------------------------------
# DoNonReferencedCredit, ie send funds to specified credit card without reference to
# a previous transaction
#
  elsif ($pprequest =~ /sendcredit/) {
		  
		my @payeraddress = (
                        SOAP::Data->name("Name" => $name)->type(""),
                        SOAP::Data->name("Street1" => $address1)->type(""),
                        SOAP::Data->name("Street2" => $address2)->type(""),
                        SOAP::Data->name("CityName" => $city)->type(""),
                        SOAP::Data->name("StateOrProvince" => $state)->type(""),
                        SOAP::Data->name("PostalCode" => $zip)->type(""),
                        SOAP::Data->name("Country" => $country)->type(""),
                       );
		push @payeraddress, SOAP::Data->name("Phone" => $phone)->type("") if $phone;
#::logDebug("PP".__LINE__.":payeraddress=".::uneval(@payeraddress));

		my @payername = (  
                        SOAP::Data->name("FirstName" => $::Values->{'b_fname'} || $::Values->{'fname'})->type(""),
                        SOAP::Data->name("LastName" => $::Values->{'b_lname'} || $::Values->{'lname'})->type(""),
					  );
		push @payername, SOAP::Data->name("MiddleName" => $::Values->{'middlename'})->type("") if $::Values->{'middlename'};
		push @payername, SOAP::Data->name("Salutation" => $::Values->{'salutation'})->type("") if $::Values->{'salutation'};
		push @payername, SOAP::Data->name("Suffix" => $::Values->{'suffix'})->type("") if $::Values->{'suffix'};
#::logDebug("PP".__LINE__.":payername=".::uneval(@payername));

		my @cardowner = (  
                        SOAP::Data->name("PayerName" => 
                        \SOAP::Data->value(
						  @payername,
						  ),
						),
                        SOAP::Data->name("Address" => 
                        \SOAP::Data->value(
						  @payeraddress,
						  ),
						),
					  );
		push @cardowner, SOAP::Data->name("Payer" => $::Values->{'email'})->type("") if $::Values->{'email'};
		push @cardowner, SOAP::Data->name("PayerID" => $::Values->{'payerid'})->type("") if $::Values->{'payerid'};
#::logDebug("PP".__LINE__.":cardowner=".::uneval(@cardowner));

		my $pan = $::CGI->{'mv_credit_card_number'};
		   $pan =~ s/\D*//g;
		my $mvccexpyear = $::Values->{'mv_credit_card_exp_year'};
		   $mvccexpyear = '20' . $mvccexpyear unless $mvccexpyear =~ /^20/;
		my @creditcard = (
                        SOAP::Data->name("CreditCardType" => $::Values->{'mv_credit_card_type'})->type(""),
                        SOAP::Data->name("CreditCardNumber" => $pan)->type(""),
                        SOAP::Data->name("ExpMonth" => $::Values->{'mv_credit_card_exp_month'})->type(""),
                        SOAP::Data->name("ExpYear" => $mvccexpyear)->type(""),
                        SOAP::Data->name("CardOwner" => 
                        \SOAP::Data->value(
						  @cardowner,
						  ),
						),
					  );
		push @creditcard, SOAP::Data->name("CVV2" => $::CGI->{'mv_credit_card_cvv2'})->type("") if $::CGI->{'mv_credit_card_cvv2'};
		push @creditcard, SOAP::Data->name("StartMonth" => $::Values->{'mv_credit_card_start_month'})->type("") if $::Values->{'mv_credit_card_start_month'};
		push @creditcard, SOAP::Data->name("StartYear" => $::Values->{'mv_credit_card_start_year'})->type("") if $::Values->{'mv_credit_card_start_month'};
		push @creditcard, SOAP::Data->name("IssueNumber" => $::Values->{'mv_credit_card_issue_number'})->type("") if $::Values->{'mv_credit_card_issue_number'};
#::logDebug("PP".__LINE__.":creditcard=".::uneval(@creditcard)); 


	   my @docreditreq = (
                    SOAP::Data->name("Amount" => $amount)->attr({"currencyID" => $currency})->type(""),
                    SOAP::Data->name("CreditCard" =>
			        \SOAP::Data->value(
					@creditcard,
					  ),
					 ),
					);
		push @docreditreq, SOAP::Data->name("Comment" => $::Values->{'vtmessage'})->type("") if $::Values->{'vtmessage'};
		push @docreditreq, SOAP::Data->name("ReceiverEmail" => $::Values->{'email'})->type("") if $::Values->{'email'};
#::logDebug("PP".__LINE__.":docreditreq=".::uneval(@docreditreq));

     $request = SOAP::Data->name("DoNonReferencedCreditRequest" =>
			       \SOAP::Data->value(
			        SOAP::Data->name("Version" => $version)->attr({xmlns=>"urn:ebay:apis:eBLBaseComponents"})->type(""),
					SOAP::Data->name("DoNonReferencedCreditRequestDetails" =>
					\SOAP::Data->value(
					  @docreditreq
				       ),
				     )->attr({ xmlns => "urn:ebay:apis:eBLBaseComponents" }),
				    ),
                  );

	    $method = SOAP::Data->name('DoNonReferencedCreditReq')->attr({xmlns => $xmlns});
	    $response = $service->call($header, $method => $request);
	    %result = %{$response->valueof('//DoNonReferencedCreditResponse')};

#::logDebug("PP".__LINE__.": result=".::uneval(%result));
		return(%result);

}
  
##
##============================================================================================
## Interchange names are on the left, Paypal on the right
##

 my %result_map;
 if ($pprequest =~ /dorequest|giropaylog/) {
    %result_map = ( qw/
		   order-id	     		TransactionID
		   pop.order-id			TransactionID
		   pop.timestamp		Timestamp
		   pop.auth-code		Ack
		   pop.status			Ack
		   pop.txn-id			TransactionID
		   pop.refund-txn-id	RefundTransactionID
		   pop.cln-id			CorrelationID
	/
    );

    for (keys %result_map) {
        $result{$_} = $result{$result_map{$_}}
           if defined $result{$result_map{$_}};
    }
  }
#::logDebug("PP".__LINE__.": ack=$result{Ack}; ppreq=$pprequest");
  if (($result{'Ack'} eq 'Success') and ($pprequest =~ /dorequest|giropay/)) {
         $result{'MStatus'} = $result{'pop.status'} = 'success';
         $result{'order-id'} ||= $order_id || $opt->{'order_id'};
#::logDebug("PP".__LINE__.": mstatus=$result{MStatus}"); 
           }
  elsif (!$result{'Ack'}) {
         $result{'MStatus'} = $result{'pop.status'} = 'failure';
         $result{'order-id'} = '';
         $result{'TxType'} = 'NULL';
         $result{'StatusDetail'} = 'UNKNOWN status - check with Paypal';
           }
  elsif ($result{'Ack'} eq 'Failure') {
         $result{'MStatus'} = $result{'pop.status'} = 'failure';
         $result{'order-id'} = $result{'pop.order-id'} = '';
         $result{'MErrMsg'} = "code $result{'ErrorCode'}: $result{'LongMessage'}\n";
      }

	$::Values->{'returnurl'} = '';
	$::Scratch->{'pprecurringbilling'} = '';

#::logDebug("PP".__LINE__." result:" .::uneval(\%result));
    return (%result);

}

#
##------------------------------------------------------------------------------------------------
#

sub getrpdetails {

	my $update = $::Session->{'rpupdate'} || '';
	my $profileID = shift || charge_param('rpprofileid') || $::Values->{'rpprofileid'};
	$::Values->{'rpprofileid'} = '';
	$::Scratch->{'rpprofileid'} = '';
	$::Session->{'rpupdate'} = '';
#::logDebug("PP".__LINE__.": getRPdetails: profileID=$profileID");
	my $request  = ( 
					  SOAP::Data->name('GetRecurringPaymentsProfileDetailsRequest' =>
					  \SOAP::Data->value(
					   SOAP::Data->name('Version' => $version)->attr({xmlns => 'urn:ebay:apis:eBLBaseComponents'})->type('xs:string'),
					   SOAP::Data->name('ProfileID' => $profileID)->type('xs:string'),
					   ),
					)->attr({xmlns => 'urn:ebay:apis:eBLBaseComponents'}),
			     );

	   my $method = SOAP::Data->name('GetRecurringPaymentsProfileDetailsReq')->attr({ xmlns => $xmlns });
	   my $response = $service->call($header, $method => $request);
		  %result = %{$response->valueof('//GetRecurringPaymentsProfileDetailsResponse')};

		 $::Scratch->{'rpdetails'} = ::uneval(%result);

		 $::Scratch->{'rpcorrelationid'} = $result{'CorrelationID'};
		 $::Scratch->{'rpprofilereference'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'RecurringPaymentsProfileDetails'}{'ProfileReference'};
		 $::Scratch->{'rpprofileid'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'ProfileID'};
		 $::Scratch->{'rpdescription'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'Description'};
		 $::Scratch->{'rpprofilestatus'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'ProfileStatus'};
		 $::Scratch->{'rpprofilestatus'} =~ s/Profile//g;
		 $::Scratch->{'rpsubscribername'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'RecurringPaymentsProfileDetails'}{'SubscriberName'};
		 $::Scratch->{'rpstartdate'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'RecurringPaymentsProfileDetails'}{'BillingStartDate'};
		 $::Scratch->{'rpstartdate'} =~ s/T/ /;
		 $::Scratch->{'rpstartdate'} =~ s/Z//;
		 $::Scratch->{'rptaxamount'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'RegularRecurringPaymentsPeriod'}{'TaxAmount'};
		 $::Scratch->{'rpshippingamount'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'RegularRecurringPaymentsPeriod'}{'ShippingAmount'};
		 $::Scratch->{'rpamount'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'RegularRecurringPaymentsPeriod'}{'Amount'};
		 $::Scratch->{'rpgrossamount'} = sprintf '%.2f', ($::Scratch->{'rpamount'} + $::Scratch->{'rpshipping'} + $::Scratch->{'rptax'});
		# $::Scratch->{'rpgrossamount'} = sprintf '%.2f', $rpgross;
		 $::Scratch->{'rpfrequency'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'RegularRecurringPaymentsPeriod'}{'BillingFrequency'};
		 $::Scratch->{'rpperiod'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'RegularRecurringPaymentsPeriod'}{'BillingPeriod'};
		 $::Scratch->{'rptotalcycles'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'RegularRecurringPaymentsPeriod'}{'TotalBillingCycles'};
		 $::Scratch->{'rpnextbillingdate'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'RecurringPaymentsSummary'}{'NextBillingDate'};
		 $::Scratch->{'rpnextbillingdate'} =~ s/T/ /g; # format for IC's 'convert-date'
		 $::Scratch->{'rpnextbillingdate'} =~ s/Z//g; 
		 $::Scratch->{'rpcyclesmade'} =  $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'RecurringPaymentsSummary'}{'NumberCyclesCompleted'};
		 $::Scratch->{'rpcyclesfailed'} =  $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'RecurringPaymentsSummary'}{'FailedPaymentCount'};
		 $::Scratch->{'rpcyclesremaining'} =  $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'RecurringPaymentsSummary'}{'NumberCyclesRemaining'};
		 $::Scratch->{'rparrears'} =  $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'RecurringPaymentsSummary'}{'OutstandingBalance'};
		 $::Scratch->{'rpmaxfailedpayments'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'MaxFailedPayments'};

		 $::Scratch->{'rptrialamount'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'TrialRecurringPaymentsPeriod'}{'Amount'};
		 $::Scratch->{'rptrialtaxamount'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'TrialRecurringPaymentsPeriod'}{'TaxAmount'};
		 $::Scratch->{'rptrialshippingamount'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'TrialRecurringPaymentsPeriod'}{'ShippingAmount'};
		 $::Scratch->{'rptrialfrequency'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'TrialRecurringPaymentsPeriod'}{'BillingFrequency'};
		 $::Scratch->{'rptrialperiod'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'TrialRecurringPaymentsPeriod'}{'BillingPeriod'};
		 $::Scratch->{'rptrialtotalcycles'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'TrialRecurringPaymentsPeriod'}{'TotalBillingCycles'};
		 my $rptrialgrossamount = $::Scratch->{'rptrialamount'} + $::Scratch->{'rptrialtaxamount'} + $::Scratch->{'rptrialshippingamount'};
		 $::Scratch->{'rptrialgrossamount'} = sprintf '%.2f', $rptrialgrossamount;
		 my $finalpaymentduedate = $result{'GetRecurringPaymentsProfileDetailsResponse'}{'FinalPaymentDueDate'};
		    $finalpaymentduedate =~ s/T/ /; # format for IC's convert-date routine
		 $::Scratch->{'rpfinalpaymentduedate'} = $finalpaymentduedate =~ s/Z//; 
		 $::Scratch->{'rpregularamountpaid'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'RegularAmountPaid'};
		 $::Scratch->{'rptrialamountpaid'} = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'TrialAmountPaid'};
		 my $rptotalpaid = $result{'GetRecurringPaymentsProfileDetailsResponseDetails'}{'AggregateAmount'};

# ### activation details not returned ...
		my $db = dbref('transactions');
		my $dbh = $db->dbh();
		my $rpdeposit_field = 'rpdeposit_' . lc($currency) || 'rpdeposit';
		my $sth = $dbh->prepare("SELECT $rpdeposit_field, rpdepositfailedaction FROM products WHERE description='$::Scratch->{rpdescription}'");
		   $sth->execute() or die $sth->errstr;
	    my @d = $sth->fetchrow_array();
		   $::Scratch->{'rpdeposit'} = $d[0];
		   $::Scratch->{'rpdepositfailedaction'} = $d[1];


		if ($update) {
			$sth = $dbh->prepare("UPDATE transactions SET rpprofilestatus='$::Scratch->{rpprofilestatus}',status='PPsub-$::Scratch->{rpprofilestatus}',txtype='PPsub-$::Scratch->{rpprofilestatus}' WHERE rpprofileid='$::Scratch->{rpprofileid}'");
			$sth->execute() or die $sth->errstr;
			$::Session->{'rpupdate'} = '';
		}

	return($result{'Ack'});
}

package Vend::Payment::PaypalExpress;

1;
