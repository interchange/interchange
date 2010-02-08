# Vend::Payment::PaypalExpress - Interchange Paypal Express Payments module
#
# Copyright (C) 2010 Zolotek Resources Ltd
# All Rights Reserved.
#
# Author: Lyn St George <info@zolotek.net>
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

=head1 Changelog

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
Based on original code by Mike Heins <mheins@perusion.com>

=cut

BEGIN {
	eval {
		package Vend::Payment;
		require SOAP::Lite or die __PACKAGE__ . " requires SOAP::Lite";
# without this next it defaults to Net::SSL which may crash
		require IO::Socket::SSL or die __PACAKGE__ . " requires IO::Socket::SSL";
		require Net::SSLeay;
	};

	if ($@) {
		$msg = __PACKAGE__ . ' requires SOAP::Lite and IO::Socket::SSL';
		::logGlobal ($msg);
		die $msg;
	}

	::logGlobal("%s v1.0.7 payment module loaded",__PACKAGE__)
		unless $Vend::Quiet or ! $Global::VendRoot;
}

package Vend::Payment;
#use SOAP::Lite +trace; # debugging only
use strict;

sub paypalexpress {
    my ($token, $header, $request, $method, $response, $in, $opt, $actual);

	foreach my $x (@_) {
		    $in = { 
		    		pprequest => $x->{'pprequest'},
		    	   }
	}

my $pprequest   = $in->{'pprequest'} || charge_param('pprequest') || 'setrequest'; # 'setrequest' must be the default for standard Paypal. 
my $username    = charge_param('id') or die "No username id\n";
my $password    = charge_param('password') or die "No password\n";
my $signature   = charge_param('signature') or die "No signature found\n"; # use this as certificate is broken
my $ppcheckreturn = $::Values->{ppcheckreturn} || 'ord/checkout';
my $checkouturl = $Tag->area({ href => "$ppcheckreturn" });

# ISO currency code, from the page for a multi-currency site or fall back to config files.
my $currency = $::Values->{currency_code} || $Vend::Cfg->{Locale}{iso_currency_code} ||
                charge_param('currency')  || $::Variable->{MV_PAYMENT_CURRENCY} || 'USD';

my $amount =  charge_param('amount') || Vend::Interpolate::total_cost() || $::Values->{amount}; # required
   $amount =~ s/^\D*//g;
   $amount =~ s/\s*//g;
   $amount =~ s/,//g;

# for a SET request
my $sandbox            = $::Values->{ppsandbox} || charge_param('sandbox') || ''; # 1 or yes to use for testing
   $sandbox            = "sandbox." if $sandbox;
my $host               = charge_param('host') ||  'api-3t.paypal.com'; #  testing 3-token system is 'api-3t.sandbox.paypal.com'.
   $host               = 'api-3t.sandbox.paypal.com' if $sandbox;
my $invoiceID          = $::Values->{inv_no} || $::Values->{mv_transaction_id} || $::Values->{order_number} || ''; # optional
my $returnURL          = $::Values->{returnurl} || charge_param('returnurl') or die "No return URL found\n"; # required
my $cancelURL          = $::Values->{cancelurl} || charge_param('cancelurl') or die "No cancel URL found\n"; # required
my $maxAmount          = $::Values->{maxamount} || '';  # optional
   $maxAmount          = sprintf '%.2f', $maxAmount;
my $orderDescription   = '';
my $address            = '';
my $reqConfirmShipping = $::Values->{reqconfirmshipping} || charge_param('reqconfirmshipping') || ''; # you require that the customer's address must be "confirmed"
my $returnFMFdetails   = $::Values->{returnfmfdetails} || charge_param('returnfmfdetails') || '0'; # set '1' to return FraudManagementFilter details
my $noShipping         = $::Values->{noshipping} || charge_param('noshipping') || ''; # no shipping displayed on Paypal pages
my $addressOverride    = $::Values->{addressoverride} || charge_param('addressoverride') || ''; # if '1', Paypal displays address given in SET request, not the one on Paypal's file
my $localeCode         = $::Values->{localecode} || $::Session->{mv_locale} || charge_param('localecode') || 'en_US';
my $pageStyle          = $::Values->{pagestyle} || charge_param('pagestyle') || ''; # set in Paypal account
my $headerImg          = $::Values->{headerimg} || charge_param('headerimg') || ''; # from your secure site
my $headerBorderColor  = $::Values->{headerbordercolor} || charge_param('headerbordercolor') || '';
my $headerBackColor    = $::Values->{headerbackcolor} || charge_param('headerbackcolor') || '';
my $payflowColor       = $::Values->{payflowcolor} || charge_param('payflowcolor') || '';
my $paymentAction      = $::Values->{paymentaction} || charge_param('paymentaction') || 'Sale'; # others: 'Order', 'Authorization'
my $buyerEmail         = $::Values->{buyeremail} || '';
my $custom             = $Session->{id}; # should not be needed
# these next taken from IC after customer has logged in, and used in '$addressOverride'
my $usebill  = $::Values->{use_billing_override} || charge_param('use_billing_override');
my $name     = $usebill ? "$::Values->{b_fname} $::Values->{b_lname}" || '' : "$::Values->{fname} $::Values->{lname}" || '';
my $address1 = $usebill ? $::Values->{b_address1} : $::Values->{address1};
my $address2 = $usebill ? $::Values->{b_address2} : $::Values->{address2};
my $city     = $usebill ? $::Values->{b_city} : $::Values->{city};
my $state    = $usebill ? $::Values->{b_state} : $::Values->{state};
my $zip      = $usebill ? $::Values->{b_zip} : $::Values->{zip};
my $country  = $usebill ? $::Values->{b_country} : $::Values->{country};
   $country = 'GB' if ($country eq 'UK'); # plonkers reject UK
   
# for a DO request
my $itemTotal     = $::Values->{itemtotal} || Vend::Interpolate::subtotal() || '';
   $itemTotal     = sprintf '%.2f', $itemTotal;
my $shipTotal     = $::Values->{shiptotal} || Vend::Interpolate::tag_shipping() || '';
   $shipTotal     = sprintf '%.2f', $shipTotal;
my $taxTotal      = $::Values->{taxtotal} || Vend::Interpolate::salestax() || '';
   $taxTotal      = sprintf '%.2f', $taxTotal;
my $handlingTotal = $::Values->{handlingtotal} || Vend::Ship::tag_handling() || '';
   $handlingTotal = sprintf '%.2f', $handlingTotal;

my $notifyURL           = $::Values->{notifyurl} || charge_param('notifyurl') || ''; # for IPN
my $buttonSource        = $::Values->{buttonsource} || charge_param('buttonsource') || ''; # for third party source
my $paymentDetailsItem  = $::Values->{paymentdetailsitem} || charge_param('paymentdetailsitem') || ''; # set '1' to include item details
my $transactionID       = $::Values->{transactionid} || ''; # returned upon success
my $correlationID       = $::Values->{correlationid} || ''; # use for any dispute with Paypal
my $refundtransactionID = $::Values->{refundtransactionid} || ''; # log for reference
my $quantity            = $::Tag->nitems() || '1';

# if $paymentDetailsItem is set, then need to pass an item amount to keep Paypal happy
my $itemAmount   = $amount / $quantity;
   $itemAmount   = sprintf '%.2f', $itemAmount;
   $amount       = sprintf '%.2f', $amount;
my $receiverType = $::Values->{receiverType} || charge_param('receivertype') || 'EmailAddress'; # used in MassPay
my $version      = '2.0';
#::logDebug("PP".__LINE__.": amount=$amount, itemamount=$itemAmount; tax=$taxTotal, ship=$shipTotal, hdl=$handlingTotal");
my $order_id  = gen_order_id($opt);

#-----------------------------------------------------------------------------------------------
# for operations through the payment terminal, eg 'masspay', 'refund' etc
my  $refundType    = $::Values->{refundtype} || 'Full'; # either 'Full' or 'Partial'
my  $memo          = $::Values->{memo} || '';
my  $orderid       = $::Values->{mv_order_id} || '';
my  $emailSubject  = $::Values->{emailsubject} || ''; # subject line of email
my  $receiverEmail = $::Values->{receiveremail} || ''; # address of refund recipient

    my %result;

    my $xmlns = 'urn:ebay:api:PayPalAPI';

	    my $service = SOAP::Lite->proxy("https://$host/2.0/")->uri($xmlns);
	    # Ignore the paypal typecasting returned
	    *SOAP::Deserializer::typecast = sub {shift; return shift};

#-------------------------------------------------------------------------------------------------
### Create the Security Header
	 my $header = SOAP::Header->name("RequesterCredentials" =>
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
 if ($pprequest eq 'setrequest') {
		   my @setreq = (
				       SOAP::Data->name("OrderTotal" => $amount)->attr({"currencyID"=>$currency})->type("cc:BasicAmountType"),
				       SOAP::Data->name("currencyID" => $currency)->type("xs:string"),
				       SOAP::Data->name("MaxAmount" => $maxAmount)->type("xs:string"),
				       SOAP::Data->name("OrderDescription" => $orderDescription)->type("xs:string"),
				       SOAP::Data->name("Custom" => $custom)->type("xs:string"),
				       SOAP::Data->name("InvoiceID" => $invoiceID)->type("xs:string"),
				       SOAP::Data->name("ReturnURL" => $returnURL)->type("xs:string"),
				       SOAP::Data->name("CancelURL" => $cancelURL)->type("xs:string"),
				       SOAP::Data->name("ReqConfirmShipping" => $reqConfirmShipping)->type("xs:string"),
				       SOAP::Data->name("NoShipping" => $noShipping)->type("xs:string"),
				       SOAP::Data->name("AddressOverride" => $addressOverride)->type("xs:string"),
				       SOAP::Data->name("LocaleCode" => $localeCode)->type("xs:string"),
				       SOAP::Data->name("PageStyle" => $pageStyle)->type("xs:string"),
				       SOAP::Data->name("PaymentAction" => $paymentAction)->type(""),
				       SOAP::Data->name("BuyerEmail" => $buyerEmail)->type("xs:string"),
				       SOAP::Data->name("cpp-header-image" => $headerImg)->type("xs:string"),
				       SOAP::Data->name("cpp-header-border-color" => $headerBorderColor)->type("xs:string"),
				       SOAP::Data->name("cpp-header-back-color" => $headerBackColor)->type("xs:string"),
				       SOAP::Data->name("cpp-payflow-color" => $payflowColor)->type("xs:string")
                        );

           my @setaddress = (
                       SOAP::Data->name("Address" =>
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
                        
          

# Destroy the token here at the start of a new request, rather than after a 'dorequest' has completed,
# as Paypal use it to reject duplicate payments resulting from clicking the final 'pay' button more
# than once.
  
   undef $result{Token};

    if (($addressOverride == '1') and ($name)) {
    push @setreq, @setaddress;
     }
	
		$request = SOAP::Data->name("SetExpressCheckoutRequest" =>
				\SOAP::Data->value(
				 SOAP::Data->name("Version" => $version)->type("xs:string"),
				 SOAP::Data->name("SetExpressCheckoutRequestDetails" =>
				 \SOAP::Data->value(@setreq
				       )
				     )
			       )
			     ) ->attr({xmlns=>"urn:ebay:apis:eBLBaseComponents"});

 	    $method = SOAP::Data->name('SetExpressCheckoutReq')->attr({xmlns=>$xmlns});
	    $response = $service->call($header, $method => $request);
	    %result = %{$response->valueof('//SetExpressCheckoutResponse')};
		$::Scratch->{token} = $result{Token};
 
   if (!$result{Token}) {
    if ($result{Ack} eq 'Failure') {
     foreach my $i ($result{Errors}) {
     	  $::Session->{errors}{PaypalExpress} .= "$i->{LongMessage}, ";
        		}
          $::Session->{errors}{PaypalExpress} =~ s/, $//;
             }
    else {
       my $accepted = uc($::Variable->{CREDIT_CARDS_ACCEPTED});
       $::Session->{errors}{PaypalExpress} = errmsg("Paypal is currently unavailable - please use our secure payment system instead. We accept $accepted cards");
             }
return $Tag->deliver({ location => $checkouturl }) 
      }

#::logDebug("PP".__LINE__.": sandbox=$sandbox; host=$host");
# Now go off to Paypal
  my $redirecturl = "https://www."."$sandbox"."paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=$result{Token}";

return $Tag->deliver({ location => $redirecturl }) 

   }


#--------------------------------------------------------------------------------------------------
### Create a GET request and method, and read response
 elsif ($pprequest eq 'getrequest') {
	    $request = SOAP::Data->name("GetExpressCheckoutDetailsRequest" =>
			 \SOAP::Data->value(
		 	  SOAP::Data->name("Version" => $version)->type("xs:string"),
		         SOAP::Data->name("Token" => $::Scratch->{token})->type("xs:string")
			 )
		   ) ->attr({xmlns=>"urn:ebay:apis:eBLBaseComponents"});
	     $method = SOAP::Data->name('GetExpressCheckoutDetailsReq')->attr({xmlns=>$xmlns});
	    $response = $service->call($header, $method => $request);
			%result = %{$response->valueof('//GetExpressCheckoutDetailsResponse')};
#::logDebug("PP".__LINE__.": Get Ack=$result{Ack}");

# populate the billing address rather than shipping address when the basket is being shipped to
# another address, eg it is a wish list.
	  if (($result{Ack} eq "Success") and ($::Values->{pp_use_billing_address} == 1)) {
		$::Values->{b_phone_day}      = $result{GetExpressCheckoutDetailsResponseDetails}{ContactPhone};
		$::Values->{email}          = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Payer};
		$::Values->{payerid}          = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerID};
		$::Values->{payerstatus}      = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerStatus};
		$::Values->{payerbusiness}    = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerBusiness};
	    $::Values->{salutation}       = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerName}{Salutation};
	    $::Values->{b_fname}          = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerName}{FirstName};
	    $::Values->{mname}            = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerName}{MiddleName};
	    $::Values->{b_lname}          = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerName}{LastName};
	    $::Values->{suffix}           = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerName}{Suffix};
	    $::Values->{address_status}   = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{AddressStatus};
	    $::Values->{b_name}           = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerName}{PayerName};
	    $::Values->{b_address1}       = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{Street1};
	    $::Values->{b_address2}       = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{Street2};
	    $::Values->{b_city}           = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{CityName};
	    $::Values->{b_state}          = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{StateOrProvince};
	    $::Values->{b_zip}            = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{PostalCode};
	    $::Values->{b_country}        = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{Country};
	    $::Values->{countryname}      = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{CountryName};
	              }

	  elsif ($result{Ack} eq "Success") {
	    $::Values->{phone_day}      = $result{GetExpressCheckoutDetailsResponseDetails}{ContactPhone} || $::Values->{phone_day} || $::Values->{phone_night};
		$::Values->{payerid}        = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerID};
		$::Values->{payerstatus}    = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerStatus};
		$::Values->{payerbusiness}  = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerBusiness};
	    $::Values->{salutation}     = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerName}{Salutation};
	    $::Values->{suffix}         = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerName}{Suffix};
	    $::Values->{address_status} = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{AddressStatus};
	  if ($addressOverride != '1') {
		$::Values->{email}          = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Payer};
	    $::Values->{fname}          = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerName}{FirstName};
	    $::Values->{mname}          = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerName}{MiddleName};
	    $::Values->{lname}          = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{PayerName}{LastName};
	    $::Values->{name}           = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{Name};
	    $::Values->{address1}       = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{Street1};
	    $::Values->{address2}       = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{Street2};
	    $::Values->{city}           = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{CityName};
	    $::Values->{state}          = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{StateOrProvince};
	    $::Values->{zip}            = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{PostalCode};
	    $::Values->{countryname}    = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{CountryName};
		$::Values->{country}        = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{Country};
	              }
		   }
		   
		$::Values->{company} = $::Values->{b_company} = $::Values->{payerbusiness};

# If shipping address and name are chosen at Paypal to be different to the billing address/name, then {name} contains 		
# the shipping name but {fname} and {lname} still contain the billing names.
   if ($::Values->{fname} !~ /$::Values->{name}/) {
       $::Values->{name} =~ /(\S*)\s+(.*)/;
       $::Values->{fname} = $1;
       $::Values->{lname} = $2;
    }
		
	   $::Session->{errors}{PaypalExpress}  = $result{Errors}{ShortMessage} if $result{Errors}{ShortMessage};
   
       $country = $::Values->{country} || $::Values->{b_country};
       $state = $::Values->{state} || $::Values->{b_state};
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
        
        $::Values->{b_state} = $state if ($::Values->{pp_use_billing_address} == 1);
        $::Values->{state} = $state;
  
  }

#------------------------------------------------------------------------------------------------
### Create a DO request and method, and read response. Not used for Giropay
 elsif ($pprequest eq 'dorequest') {
     #  $currency = 'EUR'; # set to currency different to that started with to force failure for testing
	   my @doreq  = (
				     SOAP::Data->name("OrderTotal" => $amount )->attr({"currencyID"=>$currency})->type("xs:string"),
				     SOAP::Data->name("ItemTotal" => $itemTotal )->attr({"currencyID"=>$currency})->type("xs:string"),
				     SOAP::Data->name("ShippingTotal" => $shipTotal )->attr({"currencyID"=>$currency})->type("xs:string"),
				     SOAP::Data->name("HandlingTotal" => $handlingTotal )->attr({"currencyID"=>$currency})->type("xs:string"),
				     SOAP::Data->name("TaxTotal" => $taxTotal )->attr({"currencyID"=>$currency})->type("xs:string"),
				     SOAP::Data->name("OrderDescription" => $orderDescription )->type("xs:string"),
				     SOAP::Data->name("Custom" => $custom )->type("xs:string"),
				     SOAP::Data->name("InvoiceID" => $invoiceID )->type("xs:string")
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

		  my ($item,$itm,@pdi);
		  foreach  $item (@{$::Carts->{'main'}}) {
			  $itm = {
					  number => $item->{'code'},
					  quantity => $item->{'quantity'},
					  name => Vend::Data::item_description($item),
					  amount => Vend::Data::item_price($item),
					  tax => (Vend::Data::item_price($item)/$itemTotal * $taxTotal)
					  };
		my $pdi  = (
	                SOAP::Data->name("PaymentDetailsItem" =>
	                \SOAP::Data->value(
	                 SOAP::Data->name("Name" => $itm->{name})->type("xs:string"),
	                 SOAP::Data->name("Amount" => $itm->{amount})->type("xs:string"),
	                 SOAP::Data->name("Number" => $itm->{number})->type("xs:string"),
	                 SOAP::Data->name("Quantity" => $itm->{quantity})->type("xs:string"),
	                 SOAP::Data->name("Tax" => $itm->{tax})->type("xs:string")
	                    )
	                  )->type("ebl:PaymentDetailsItemType")
	                );
	push @pdi, $pdi;
	  }
    
	push @doreq, SOAP::Data->name("NotifyURL" => $notifyURL )->type("xs:string") if $notifyURL;
	push @doreq, SOAP::Data->name("ButtonSource" => $buttonSource )->type("xs:string") if $buttonSource;
	push @doreq, SOAP::Data->name("ReturnFMFDetails" => '1' )->type("xs:boolean") if $returnFMFdetails == '1';
	push @doreq, @sta if $addressOverride  == '1';
	push @doreq, @pdi if $paymentDetailsItem == '1';

	    $request = SOAP::Data->name("DoExpressCheckoutPaymentRequest" =>
			       \SOAP::Data->value(
			        SOAP::Data->name("Version" => $version)->type("xs:string"),
			        SOAP::Data->name("DoExpressCheckoutPaymentRequestDetails" =>
			        \SOAP::Data->value(
			         SOAP::Data->name("Token" => $::Scratch->{token})->type("xs:string"),
			         SOAP::Data->name("PaymentAction" => $paymentAction)->type(""),
			         SOAP::Data->name("PayerID" => $::Values->{payerid} )->type("xs:string"),
			         SOAP::Data->name("PaymentDetails" =>
			         \SOAP::Data->value( @doreq
				     )
			       )
			     )
			   )
			 )
		   ) ->attr({xmlns=>"urn:ebay:apis:eBLBaseComponents"});

	    $method = SOAP::Data->name('DoExpressCheckoutPaymentReq')->attr({xmlns=>$xmlns});
	    $response = $service->call($header, $method => $request);
	    %result = %{$response->valueof('//DoExpressCheckoutPaymentResponse')};
#::logDebug("PP".__LINE__.": Do Ack=$result{Ack}; ppreq=$pprequest");
	  
	  if ($result{Ack} eq "Success") {
	    $Session->{payment_result}{Status} = 'Success';
	    $result{TransactionID}       = $result{DoExpressCheckoutPaymentResponseDetails}{PaymentInfo}{TransactionID};
	    $result{PaymentStatus}       = $result{DoExpressCheckoutPaymentResponseDetails}{PaymentInfo}{PaymentStatus};
	    $result{TransactionType}     = $result{DoExpressCheckoutPaymentResponseDetails}{PaymentInfo}{TransactionType};
	    $result{PaymentDate}         = $result{DoExpressCheckoutPaymentResponseDetails}{PaymentInfo}{PaymentDate};
	    $result{ParentTransactionID} = $result{DoExpressCheckoutPaymentResponseDetails}{PaymentInfo}{ParentTransactionID};
	    $result{PaymentType}         = $result{DoExpressCheckoutPaymentResponseDetails}{PaymentInfo}{PaymentType};
	    $result{PendingReason}       = $result{DoExpressCheckoutPaymentResponseDetails}{PaymentInfo}{PendingReason};
	    $result{PaymentDate}         = $result{DoExpressCheckoutPaymentResponseDetails}{PaymentInfo}{PaymentDate};
	    $result{ReasonCode}          = $result{DoExpressCheckoutPaymentResponseDetails}{PaymentInfo}{ReasonCode};
	    $result{FeeAmount}           = $result{DoExpressCheckoutPaymentResponseDetails}{PaymentInfo}{FeeAmount};
	    $result{ExchangeRate}        = $result{DoExpressCheckoutPaymentResponseDetails}{PaymentInfo}{ExchangeRate};

			    }
 	  else  {
	    $result{ErrorCode}    = $result{Errors}{ErrorCode};
	    $result{ShortMessage} = $result{Errors}{ShortMessage};
	    $result{LongMessage}  = $result{Errors}{LongMessage};
		$::Session->{errors}{"PaypalExpress error"}  = $result{Errors}{LongMessage};
		    }
#::logDebug("PP".__LINE__.": errors=$result{ShortMessage}");
		
	}


#-------------------------------------------------------------------------------------------------
# REFUND transaction
 elsif ($pprequest eq 'refund') {

	   my @refreq = (
                    SOAP::Data->name("Version" => $version)->type("xs:string")->attr({xmlns=>"urn:ebay:apis:eBLBaseComponents"}),
                    SOAP::Data->name("TransactionID" => $transactionID)->type("ebl:TransactionId"),
                    SOAP::Data->name("RefundType" => $refundType)->type(""),
                    SOAP::Data->name("Memo" => $memo)->type("xs:string")
                     );

   if ($refundType eq 'Partial') {
    push @refreq,  SOAP::Data->name("Amount" => $amount)->attr({"currencyID"=>$currency})->type("cc:BasicAmountType")
                  }

     $request = SOAP::Data->name("RefundTransactionRequest" =>
                \SOAP::Data->value( @refreq
                    )
                  ) ->type("ns:RefundTransactionRequestType");

	    $method = SOAP::Data->name('RefundTransactionReq')->attr({xmlns=>$xmlns});
	    $response = $service->call($header, $method => $request);
	    %result = %{$response->valueof('//RefundTransactionResponse')};
	    	
	    	if ($result{Ack} eq "Success") {
	  		$::Session->{payment_result}{Terminal} = 'success';
	      	$::Session->{payment_result}{RefundTransactionID} = $result{RefundTransactionResponse}{RefundTransctionID};
	    		}
		}

#-------------------------------------------------------------------------------------------------
# MASSPAY transaction
 elsif ($pprequest eq 'masspay') {
       # TODO: handle multiple entries
    my $receiverlist = $::Values->{receiverlist};
		if ($receiverType eq 'EmailAddress') {
		$receiverType = SOAP::Data->name("ReceiverEmail" => $::Values->{email})->type("ebl:EmailAddressType");
			}
		else {
		$receiverType = SOAP::Data->name("ReceiverID" => $::Values->{payerid})->type("xs:string");
		}

	foreach my $rx (split /\n/, $receiverlist) {
		my @mpi = (
                  SOAP::Data->name("MassPayItem" =>
                   \SOAP::Data->value(
                    $receiverType,
                    SOAP::Data->name("Amount" => $amount)->attr({ "currencyID"=>$currency })->type("ebl:BasicAmountType"),
                    SOAP::Data->name("UniqueID" => $orderid)->type("xs:string"),
                    SOAP::Data->name("Note" => $memo)->type("xs:string")
                    )
                 ) ->type("ns:MassPayItemRequestType")
              );

	$request = SOAP::Data->name("MassPayRequest" =>
			   \SOAP::Data->value(
                SOAP::Data->name("Version" => $version)->type("xs:string")->attr({ xmlns=>"urn:ebay:apis:eBLBaseComponents" }),
			    SOAP::Data->name("EmailSubject" => $emailSubject)->type("xs:string"),
			    SOAP::Data->name("ReceiverType" => $receiverType)->type(""),
                @mpi
                   )
                 ) ->type("ns:MassPayRequestType");

	    $method = SOAP::Data->name('MassPayReq')->attr({ xmlns=>$xmlns });
	    $response = $service->call($header, $method => $request);
	    %result = %{$response->valueof('//MassPayResponse')};
	  	$::Session->{payment_result}{Terminal} = 'success' if $result{Ack} eq 'Success';
#::logDebug("PP".__LINE__.":response=$result{Ack},cID=$result{CorrelationID}");
			}
	 	$::Values->{receiverlist} = '';
      }

#-------------------------------------------------------------------------------------------------
    # Interchange names are on the left, Paypal on the right
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
  if (($result{Ack} eq 'Success') and ($pprequest =~ /dorequest|giropay/)) {
         $result{MStatus} = $result{'pop.status'} = 'success';
         $result{'order-id'} ||= $opt->{order_id};
#::logDebug("PP".__LINE__.": mstatus=$result{MStatus}"); 
           }
  elsif (!$result{Ack}) {
         $result{MStatus} = $result{'pop.status'} = 'success';
         $result{'order-id'} ||= $opt->{order_id};
         $result{'TxType'} = 'NULL';
         $result{'StatusDetail'} = 'UNKNOWN status - check with Paypal before dispatching goods';
           }
  elsif ($result{Ack} eq 'Failure') {
         $result{MStatus} = $result{'pop.status'} = 'failure';
         $result{'order-id'} = $result{'pop.order-id'} = '';
         $result{MErrMsg} = "code $result{ErrorCode}: $result{LongMessage}\n";
      }

delete $::Values->{returnurl};

#::logDebug("PP".__LINE__." result:" .::uneval(\%result));
    return (%result);

}

package Vend::Payment::PaypalExpress;

1;
