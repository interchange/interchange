# Vend::Payment::PaypalExpress - Interchange Paypal Express Payments module
#
# Copyright (C) 2009 Zolotek Resources Ltd
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
'Request API Credential' -> 'Signature'. This will generate a user id, password and signature.

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

Deactivate the MV_PAYMENT_MODE variable in catalog.cfg and products/variable.txt.

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

Within the 'credit_card' section of etc/profiles.order change both instances of
"MV_PAYMENT_MODE" to "MV_PAYMENT_BANK"
and add
&set=psp __MV_PAYMENT_BANK__
&set=mv_payment_route authorizenet
(or your preferred gateway) as the last entries in the section.

and then add
Variable MV_PAYMENT_BANK "foo"
to catalog.cfg, where "foo" is the name of your gateway or acquirer, formatted as you want it to appear
on the receipt. Eg, "Bank of America" (rather than boa), "AuthorizeNet" (rather than authorizenet).

In etc/log_transction, change
[elsif variable MV_PAYMENT_MODE] to [elsif value mv_order_profile eq credit_card]
and within the same section change the following two instances of
[var MV_PAYMENT_MODE] to [value mv_payment_route]

Just after the credit_card section, add the following:

[elsif value mv_order_profile eq paypalexpress]
	[calc]
		return if $Scratch->{tmp_total} == $Scratch->{tmp_remaining};
		my $msg = sprintf "Your Paypal account was charged %.2f", $Scratch->{tmp_remaining};
		$Scratch->{pay_cert_total} = $Scratch->{tmp_total} - $Scratch->{tmp_remaining};
		$Scratch->{charge_total_message} = $msg;
		return "Paypal will be charged $Scratch->{tmp_remaining}";
	[/calc]
	Charging with payment mode=paypalexpress
	[tmp name="charge_succeed"][charge route="paypalexpress" pprequest="dorequest" amount="[scratch tmp_remaining]" order_id="[value mv_transaction_id]"][/tmp]
	[if scratch charge_succeed]
	[then]
	[set do_invoice]1[/set]
	[set do_payment]1[/set]
	Real-time charge succeeded. ID=[data session payment_id] amount=[scratch tmp_remaining]
	[/then]
	[else]
	Real-time charge FAILED. Reason: [data session payment_error]
	[calc]
		for(qw/
				charge_total_message
				pay_cert_total
		/)
		{
			delete $Scratch->{$_};
		}
		die errmsg(
				"Real-time charge failed. Reason: %s\n",
				errmsg($Session->{payment_error}),
			);
	[/calc]
	[/else]
	[/if]
[/elsif]
This runs the final Paypal charge route, handles deductions for gift certificates from the amount
payable, and handles errors in the same way as the previous credit_card section does.

Add into the end of the "[import table=transactions type=LINE continue=NOTES no-commit=1]" section
of etc/log_transaction:

psp: [value psp]
pptransactionid: [calc]$Session->{payment_result}{TransactionID}[/calc]
pprefundtransactionid: [calc]$Session->{payment_result}{RefundTransactionID}[/calc]
ppcorrelationid: [calc]$Session->{payment_result}{CorrelationID};[/calc]

and add these 4 new columns into your transactions table.
You will have records of which transactions went through which payment service providers, as well
as Paypal's returned IDs. The CorrelationID is the one you need in any dispute with them.

Add these lines into the body of the 'Go to Paypal' button that sends the customer to Paypal.
      [button
        normal stuff
            ]
          [run-profile name=paypalexpress]
          [if type=explicit compare="[error all=1 show_var=1 keep=1]"]
          mv_nextpage=ord/checkout
          [/if]
          [charge route="paypalexpress" pprequest="setrequest"]
          mv_todo=return
       [/button]
Note that 'mv_todo' is return, not submit. 

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

The flow is: the first button for Paypal goes to the 'paypalsetrequest' page, which sends a request
to Paypal to initialise the transaction and gets a token back in return. If Paypal fails to send back
a token, then the module refreshes that page with an error message suggesting that the customer should
use your normal payment service provider and shows the cards that you accept. Once the token is read, then
your customer is taken to Paypal to login and choose his payment method. Once that is done, he returns
to us and hits the 'paypalgetrequest' page. This gets his full address as held by Paypal, bounces to
the final 'paypalcheckout' page and populates the form with his address details. If you have both shipping
and billing forms on that page, the shipping address will be populated by default but you may force
the billing form to be populated instead by sending
<input type=hidden name=pp_use_billing_address value=1>
at the initial 'setrequest' stage. Then the customer clicks the final 'pay now' button and the
transaction is done.


Options that may be set either in the route or in the page:
 * reqconfirmshipping - this specifies that a Paypal customer must have his address 'confirmed'
 * addressoverride - this specifies that you will ship only to the address IC has on file (including
   the name and email); your customer needs to login to IC first before going to Paypal
   other options are also settable.

Testing: while the obvious test choice is to use their sandbox, I've always found it a bit of a dog's breakfast
   and never trusted it. Much better to test on the live site, and just recyle money between your personal and
   business accounts at minimal cost to yourself, but with the confidence of knowing that test results are correct.

=head1 Changelog

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
		require IO::Socket::SSL or die __PACAKGE__ . "requires IO::Socket::SSL";
		require Net::SSLeay;
	};

	if ($@) {
		$msg = __PACKAGE__ . ' requires SOAP::Lite and IO::Socket::SSL';
		::logGlobal ($msg);
		die $msg;
	}

	::logGlobal("%s v1.0.2d payment module loaded",__PACKAGE__)
		unless $Vend::Quiet or ! $Global::VendRoot;
}

package Vend::Payment;

sub paypalexpress {
 use SOAP::Lite +trace; # debugging only
    my ($token, $header, $request, $method, $response, $in);

### Check that shipping is not zero unless it's allowed to be, and if so return to the checkout
my $ppcheckzeroshipping =  $::Values->{pp_check_zero_shipping} || charge_param('pp_check_zero_shipping') || '';
my $ppcheckreturn = $::Values->{ppcheckreturn} || 'ord/checkout';
my $checkouturl = $Tag->area({ href => "$ppcheckreturn" });
my $shipmode = $::Values->{mv_shipmode} || charge_param('default_shipmode') || 'upsg';
my $freeshipping = delete $::Scratch->{freeshipping} || 'no'; # set to 'yes' in a custom 'free shipping' routine to allow free shipping with shipping weight > 0
my ($shiperror, $shipweight, $shipfree, $shipcost) = split(/:/, $::Tag->shipping({ mode => $shipmode, label => 1, noformat => 1, format => "%M=%e:%T:%F:%F" }));
if ($shipcost !~ /\d+/) {$shipcost = 0}
 
    $::Scratch->{zeroshipping} = '';
if ($shipfree =~ /free/i || $freeshipping eq 'yes' || $shipweight == 0) {
	$::Scratch->{zeroshipping} = '1'; # for use in final shipping page
			}
  elsif (($ppcheckzeroshipping == 1 ) and (($shiperror =~ /Not enough information/i) || ($shipcost == 0) || ($shipcost != $shipping))) {
	my $msg = errmsg("Please check that your shipping cost is correct - thank you.");
    $Vend::Session->{errors}{Shipping} = $msg;
$::Tag->tag({ op => 'header', body => <<EOB });
Status: 302 moved
Location: $checkouturl
EOB
}

# find some base values
	foreach my $x (@_) {
		    $in = { 
		    		pprequest => $x->{'pprequest'},
		    		username  => $x->{'id'},
		    		password  => $x->{'password'},
		    		signature => $x->{'signature'}	
		    	   }
	}

my $pprequest = $in->{'pprequest'} || charge_param('pprequest') || 'setrequest'; # 'setrequest', 'getrequest', 'dorequest'. 
my $username  = $in->{'username'}  || charge_param('id') or die "No username id\n";
my $password  = $in->{'password'}  || charge_param('password') or die "No password\n";
my $signature = $in->{'signature'} || charge_param('signature') or die "No signature found\n"; # use this as certificate is broken
my $host      = $::Values->{'pphost'} || charge_param('host') ||  'api-3t.paypal.com'; #  testing 3-token system is 'api-3t.sandbox.paypal.com'.
my $ca2state  = $::Values->{'ca_2letter_state'} || charge_param('ca_2letter_state') || '1'; # 0 or no to not convert Canadian state/province to uppercased 2 letter variant.

# ISO currency code, from the page for a multi-currency site or fall back to config files.
my $currency = $::Values->{currency_code} || $Vend::Cfg->{Locale}{iso_currency_code} ||
                charge_param('currency')  || $::Variable->{MV_PAYMENT_CURRENCY} || 'USD';

my $amount =  Vend::Interpolate::total_cost() || $::Values->{amount}; # required
   $amount =~ s/^\D*//g;
   $amount =~ s/\s*//g;
   $amount =~ s/,//g;

# for a SET request
my $sandbox            = $::Values->{ppsandbox} || charge_param('sandbox') || ''; # 1 or yes to use for testing
my $invoiceID          = $::Values->{inv_no} || $::Values->{mv_transaction_id} || $::Values->{order_number} || ''; # optional
my $returnURL          = $::Values->{returnurl} || charge_param('returnurl') or die "No return URL found\n"; # required
my $cancelURL          = $::Values->{cancelurl} || charge_param('cancelurl') or die "No cancel URL found\n"; # required
my $maxAmount          = $::Values->{maxamount} || '';  # optional
   $maxAmount          = &ppcommify($maxamount);
my $orderDescription   = '';
my $address            = '';
my $reqConfirmShipping = $::Values->{reqconfirmshipping} || charge_param('reqconfirmshipping') || ''; # you require that the customer's address must be "confirmed"
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
my $name               = "$::Values->{fname} $::Values->{lname}" || '';
my $address1           = $::Values->{address1};
my $address2           = $::Values->{address2};
my $city               = $::Values->{city};
my $state              = $::Values->{state};
my $zip                = $::Values->{zip};
my $country            = $::Values->{country};
   if ($country eq 'UK') {$country = 'GB'}; # plonkers reject UK
   
# for a DO request
my $itemTotal     = $::Values->{itemtotal} || Vend::Interpolate::subtotal() || '';
   $itemTotal     = &ppcommify($itemtotal);
my $shipTotal     = $::Values->{shiptotal} || Vend::Interpolate::shipping($::Values->{mv_shipmode}) || '';
   $shipTotal     = &ppcommify($shiptotal);
my $taxTotal      = $::Values->{taxtotal} || Vend::Interpolate::salestax() || '';
   $taxTotal      = &ppcommify($taxtotal);
my $handlingTotal = $::Values->{handlingtotal} || Vend::Ship::tag_handling() || '';
   $handlingTotal = &ppcommify($handlingtotal);

my $notifyURL           = $::Values->{notifyurl} || charge_param('notifyurl') || ''; # for IPN
my $buttonSource        = $::Values->{buttonsource} || charge_param('buttonsource') || ''; # for third party source
my $paymentDetailsItem  = $::Values->{paymentdetailsitem} || charge_param('paymentdetailsitem') || ''; # set '1' to include item details
my $transactionID       = $::Values->{transactionid} || ''; # returned upon success
my $correlationID       = $::Values->{correlationid} || ''; # use for any dispute with Paypal
my $refundtransactionID = $::Values->{refundtransactionid} || ''; # log for reference
my $quantity            = $::Tag->nitems() || '1';

# if $paymentDetailsItem is set, then need to pass an item amount to keep Paypal happy
my $itemAmount   = $amount / $quantity;
   $itemAmount   = &ppcommify($itemAmount);
   $amount       = &ppcommify($amount);
my $receiverType = $::Values->{receiverType} || charge_param('receivertype') || 'EmailAddress'; # used in MassPay
my $version      = '2.0';

    $order_id  = gen_order_id($opt);

#-----------------------------------------------------------------------------------------------
# for operations through the payment terminal, eg 'masspay', 'refund' etc
my  $refundType    = $::Values->{refundtype} || 'Full'; # either 'Full' or 'Partial'
my  $memo          = $::Values->{memo} || '';
my  $orderid       = $::Values->{mv_order_id} || '';
my  $emailSubject  = $::Values->{emailsubject} || ''; # subject line of email
my  $receiverEmail = $::Values->{receiveremail} || ''; # address of refund recipient

    my %result;

    my $xmlns = 'urn:ebay:api:PayPalAPI';

	    $service = SOAP::Lite->proxy("https://$host/2.0/")->uri($xmlns);
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
   delete $::Scratch->{token};
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
    if ($result{Errors}{ErrorCode}) {
       $::Session->{errors}{PaypalExpress} = $result{Errors}{LongMessage};
             }
    else {
       my $accepted = uc($::Variable->{CREDIT_CARDS_ACCEPTED});
       $::Session->{errors}{PaypalExpress} = errmsg("Paypal has failed to respond correctly - please use our secure payment system instead. We accept $accepted cards");
             }
$::Tag->tag({ op => 'header', body => <<EOB });
Status: 302 moved
Location: $checkouturl
EOB
return();
      }

# Write full order to orders/paypal using pp$date.$session_id file name as failsafe backup in case order 
# route fails - if it does fail PP will still take the customer's money. IC's routine in Order.pm populates 
# the basket but not the address at this point: we want both if available
	
	my ($item, $itm, $basket);
	my $date = $Tag->time({ body => "%Y%m%d%H%M" });
	my $fn = Vend::Util::catfile(
				charge_param('orders_dir') || 'orders/paypal',
				"pp$date.$::Session->{id}"  
			);
	
	mkdir "orders/paypal", 0775 unless -d "orders/paypal";
	
	foreach  $item (@{$::Carts->{'main'}}) {
	    $itm = {
	    		code => $item->{'code'},
				quantity => $item->{'quantity'},
				description => Vend::Data::item_description($item),
				price => Vend::Data::item_price($item),
				subtotal => Vend::Data::item_subtotal($item)
				};
   $basket .= <<EOB;
Item = $itm->{code}, "$itm->{description}"; Price = $itm->{price}; Qty = $itm->{quantity}; Subtotal = $itm->{subtotal} 
EOB
 }
   $basket .= <<EOB;
(Neither tax nor shipping had been calculated when this record was made)
Delivery address:
$::CGI->{fname} $::CGI->{lname}
$::CGI->{address1}  $::CGI->{address2}
$::CGI->{city}
$::CGI->{state} $::CGI->{zip}
$::CGI->{country}
EOB

   Vend::Util::writefile( $fn, $basket )
				or ::logError("Paypal error writing failsafe order $fn: $!");

# Now go off to Paypal
  my $sbx = 'sandbox.' if $sandbox;
  my $redirecturl = "https://www."."$sbx"."paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=$result{Token}";

$::Tag->tag({ op => 'header', body => <<EOB });
Status: 302 moved
Location: $redirecturl
EOB

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

# populate the billing address rather than shipping address when the basket is being shipped to
# another address, eg it is a wish list.
	  if (($result{Ack} eq "Success") and ($::Values->{pp_use_billing_address} == 1)) {
		$::Values->{b_phone_day}      = $result{GetExpressCheckoutDetailsResponseDetails}{ContactPhone};
		$::Values->{b_email}          = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Payer};
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
	    $::Values->{country}        = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{Country};
	    $::Values->{countryname}    = $result{GetExpressCheckoutDetailsResponseDetails}{PayerInfo}{Address}{CountryName};
	              }
		   }

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
  if (($country eq 'CA') and ($ca2state =~ /1|y/)) {
    my $db  = dbref('state') or warn errmsg("PP cannot open state table");
    my $dbh = $db->dbh() or warn errmsg("PP cannot get handle for tbl 'state'");
    my $sth = $dbh->prepare("SELECT state FROM state WHERE name='$state' AND country='CA'");
       $sth->execute() or warn errmsg("PP cannot execute at ln610");
       $state = $sth->fetchrow() or warn errmsg("PP no state unless defined $state");
       
       $::Values->{b_state} = $state if ($::Values->{pp_use_billing_address} == 1);
       $::Values->{state} = $state;
      }
   }

#------------------------------------------------------------------------------------------------
### Create a DO request and method, and read response
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

	    my @pdi  = (
	                SOAP::Data->name("PaymentDetailsItem" =>
	                \SOAP::Data->value(
	                 SOAP::Data->name("Name" => $name)->type("xs:string"),
	                 SOAP::Data->name("Amount" => $itemAmount)->type("xs:string"),
	                 SOAP::Data->name("Number" => $itemCode)->type("xs:string"),
	                 SOAP::Data->name("Quantity" => $quantity)->type("xs:string"),
	                 SOAP::Data->name("Tax" => $tax)->type("xs:string")
	                    )
	                  )->type("ebl:PaymentDetailsItemType")
	                );

	if ($notifyURL) {push @doreq,SOAP::Data->name("NotifyURL" => $notifyURL )->type("xs:string")}
	if ($buttonSource) {push @doreq, SOAP::Data->name("ButtonSource" => $buttonSource )->type("xs:string")}
	if ($addressOverride  == '1') {push @doreq, @sta }
	if ($paymentDetailsItem == '1') {push @doreq, @pdi }

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
		}

#-------------------------------------------------------------------------------------------------
    # Interchange names are on the left, Paypal on the right
 my %result_map;
 if ($pprequest eq 'dorequest') {
    %result_map = ( qw/
		   order-id	     		TransactionID
		   pop.order-id			TransactionID
		   pop.timestamp		Timestamp
		   pop.auth-code		Ack
		   pop.status			Ack
		   pop.txn-id			TransactionID
		   pop.refund-txn-id	RefundTransactionID
		   pop.statusdetail		Errors.LongMessage
		   pop.cln-id			CorrelationID
	/
    );

    for (keys %result_map) {
        $result{$_} = $result{$result_map{$_}}
           if defined $result{$result_map{$_}};
    }
  }

  if (($result{Ack} eq 'Success') and ($pprequest eq 'dorequest')) {
         $result{MStatus} = $result{'pop.status'} = 'success';
         $result{'order-id'} ||= $opt->{order_id};
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


    return (%result);

}

sub ppcommify {
    local($_) = shift;
    $_ = sprintf '%.2f', $_;
    1 while s/^(-?\d+)(\d{3})/$1,$2/;
    return $_;
}

package Vend::Payment::PaypalExpress;

1;