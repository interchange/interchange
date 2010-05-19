# Vend::Payment::GoogleCheckout - Interchange Google Checkout support
#
# GoogleCheckout.pm, v 0.7.3, September 2009
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

package Vend::Payment::GoogleCheckout;

=head1 Interchange GoogleCheckout support

 http://kiwi.zolotek.net is the home page with the latest version. Also to be found on
 Kevin Walsh's excellent Interchange site,  http://interchange.rtfm.info.

=head1 AUTHORS

 Lyn St George <info@zolotek.net>

=head1 CREDITS

 Steve Graham, mrlock.com, debugging and documentation
 Andy Smith, tvcables.co.uk, debugging and documentation


=head1 PREREQUISITES

XML::Simple and any of its prerequisites (eg XML::Parser or XML::SAX)
MIME::Base64
these should be found anyway on any well-used perl installation. This version was built especially 
without the Google libraries, so as to work on old machines with perl 5.6.1 and similarly vintaged
OSes, and only need XML::Simple. 

Interchange.cfg should contain this line, with args extra to 'rand' for current UTF8 problems:
SafeUntrap  rand require caller dofile print entereval

=head1 DESCRIPTION

This integrates Google Checkout quite tightly into Interchange - it is expected that all coupons,
gift certificates, discounts, tax routines and shipping will be processed by Interchange before
sending the customer to Google. The customer will see the basket, tax, shipping and total cost
when he arrives there. The shipping is sent as a final value, while the tax is sent as a rate for
Google to calculate with. The total cost is calculated by Google, and there is the possibility of
penny differences due to rounding errors or different rounding methods employed in different countries.
As Google won't accept final tax or total cost figures this cannot be helped.

This module will authorise and optionally charge the customer's card for the purchase. It will handle
all IPNs (notifications sent back by Google of various events in the process) and both log the results
and send emails to the merchant and customer as appropriate. IPNs relating to chargebacks, refunds
and cancellations are included in this. It can handle commands sent through an admin panel - though
the current IC panel is not set up to send these. Commands relating to 'charge', 'refund', 'cancel' etc
would normally be sent through the Google admin panel, but the resulting IPNs are handled by this module.

In the interests of tighter integration and simplicity, the consensus of opinion has been to allow
shipping to only the address taken by Interchange. This means that the shipping charge and tax rate
will be correct, but also means that the customer cannot choose another address which he may have on
file at Google - if he does then the system will tell him that "Merchant xx does not ship to this
address". He of course has the option of clicking "edit basket" and changing his address at Interchange
to suit. You may want to display some sort of note to this effect prior to sending the customer to
Google. If delivery is to a US address then the restriction is to the state and the first 3 digits of
the zip code; if to anywhere else in the world then the restriction is to that country and the first
3 characters of the postal code (or fewer characters if fewer were entered - if no postal code was
entered then the whole country is allowed).

It is likely that I will build another version which does allow the customer to change his address whilst at
Google, as this limitation is a little too harsh and not at all helpful for good customer relations. 

=head2 NOTE
##########################################################################################################
# While you can send &amp; and have it returned safely, you cannot send &lt;, &gt; or similar in the     #
# description field, as it will cause IC to throw an error when Google returns the XML. Even if you send #
# these as &#x3c; and similar UTF-8 entities, Google will return them in the &lt; format.                #
#                                                                                                        #
# Note also that you can only send the currency that is "associated with your seller account", as        #
# defined by Google. There is no option to configure this, and they select it according to the country   #
# you registered in your sign-up account. Nor can you do recurring/subscription billing.                 #                                              #
##########################################################################################################

=head1 SYNOPSIS

Go to http://checkout.google.com and set up a seller's account. They will give you a merchantid and
a merchantkey, which you need to enter into the payment route as described below. While there, go to
the "Settings" tab, then the "Integration" left menu item, and set the radio button for "XML call back",
and enter the URL to your callback page -  https://your_site/ord/gcoipn.

Place this module in your Vend/Payment/ directory, and call it in interchange.cfg with:
Require module Vend::Payment::GoogleCheckout

Add these configuration options to the new Google payment route in catalog.cfg:
Route googlecheckout merchantid  (as given to you by Google at sign-up)
Route googlecheckout merchantkey (as given to you by Google at sign-up)
Route googlecheckout googlehost  'https://checkout.google.com/cws/v2/Merchant' # live
Route googlecheckout gcoipn_url http://your_url/cgi_link/ord/gcoipn (replace 'your_url' and 'cgi_link' with yours)
Route googlecheckout currency    'GBP'  (or USD, or any other ISO code accepted by Google)
Route googlecheckout edit_basket_url (eg 'http://your_url/cgi_link/ord/basket')
Route googlecheckout continue_shopping_url (eg, http://your_url/cgi_link/index)
Route googlecheckout bypass_authorization  (1 to bypass, empty to use. See below for details)
Route googlecheckout default_taxrate (a decimal, eg '0.06', in case the calculation fails)
Route googlecheckout sender_email (email address appearing in the 'from' and 'reply-to' fields)
Route googlecheckout merchant_email (email address to which the order should be sent)
Route googlecheckout receipt_from_merchant (1 to send an email receipt to the customer)
Route googlecheckout email_auth_charge ('charge' to send receipt after card has been charged, 'auth' after card has been authorised)
Route googlecheckout html_mail ('1' to send HTML instead of plain text mail)
Route googlecheckout avs_match_accepted ('full' for full match where AVS is available, 'partial' for partial match, 'none' for no match required. Default is 'partial')
Route googlecheckout cv2_match_accepted ('yes' for match required, 'none' for no match required. Default is 'yes')
Route googlecheckout default_country (2 letter ISO country code; use if not taking a delivery country at checkout, otherwise omit)
Route googlecheckout default_state (* if you want to allow all states within a country, or omit)
Route googlecheckout gco_diagnose (1 if you want to return diagnostics, empty otherwise)
Variable	MV_HTTP_CHARSET	UTF-8
The last is essential, otherwise GCO will repeat the 'new_order_notification' message ad infinitum and
never proceed any further. You will be given no clue as to why this is happening. 

NB:/ Apache is not built by default to make the HTTP_AUTHORIZATION header available to the environment,
and so you will either need to rebuild it or set 'bypass_authorization' to 1 - this latter will not
check the returned header to see that it contains your merchantid and merchantkey. Google recommend that
you make this check, but it's your choice.

Add these order routes to catalog.cfg
Route googlecheckout <<EOF
	attach            0
	empty             1
	default           1
	supplant          1
	no_receipt        1
	report            etc/log_transaction
	track             logs/tracking.asc
	counter_tid       logs/tid.counter
EOF

Route gco_final master 1
Route gco_final cascade "copy_user main_entry"
Route gco_final empty 	1
Route gco_final supplant 1
Route gco_final no_receipt 1
Route gco_final email __ORDERS_TO__

The 'edit basket' URL is available to customers when they are at Google, and lets them change either
the basket contents or the delivery address.

Create a GoogleCheckout button on your checkout page, including the order profile and route like so:
  [button
    mv_click=google
    text="GoogleCheckout"
    hidetext=1
    form=checkout
   ]
   mv_order_profile=googlecheckout
   mv_order_route=googlecheckout
   mv_todo=submit
  [/button]

Create a page in pages/ord/ called gcoipn.html, consisting of this:
[charge route="googlecheckout" gcorequest="callback"]
This page is the target of all IPN callbacks from Google, and will call the payment module in the
correct mode.

To have GoogleCheckout co-operate with your normal payment service provider, eg Authorizenet, do the
following:

Add to etc/profiles.order:

__NAME__                            googlecheckout
__COMMON_ORDER_PROFILE__
&fatal = yes
email=required
email=email
&set=mv_payment GCO
&set=psp GCO
&set=mv_payment_route googlecheckout
&set=mv_order_route googlecheckout
&final = yes
&setcheck = payment_method googlecheckout
__END__
or, if you want to use GCO as a 'Buy now' button without taking any customer details, then omit the
__COMMON_ORDER_PROFILE__ and the two 'email=...' lines above. Google are in fact quite finicky about
you not taking your customer's details, so you have the option of complying with Google or complying
with your own policy.

You must have MV_PAYMENT_MODE set in products/variable.txt to either your standard payment processor
or to 'googlecheckout'; though you may instead set this in catalog.cfg rather than variable txt as:
Variable MV_PAYMENT_MODE googlecheckout

Within the 'credit_card' section of etc/profiles.order leave
"MV_PAYMENT_MODE" 
as set and add
&set=psp __MV_PAYMENT_PSP__
&set=mv_payment_route authorizenet
(or your preferred gateway) as the last entries in the section.

and then add
Variable MV_PAYMENT_PSP "foo"
to catalog.cfg, where "foo" is the name of your gateway or acquirer, formatted as you want it to appear
on the receipt. Eg, "Bank of America" (rather than boa), "AuthorizeNet" (rather than authorizenet).


Run the following at a MySQL prompt to add the requisite fields to your transactions table:
(with thanks to Steve Graham)

ALTER TABLE `transactions` ADD `gco_order_number` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci ,
ADD `gco_buyers_id` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `gco_fulfillment_state` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `gco_serial_number` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `gco_avs_response` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `gco_cvn_response` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `gco_protection` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `gco_cc_number` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `gco_timestamp` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `gco_reason` TEXT CHARACTER SET utf8 COLLATE utf8_general_ci ,
ADD `gco_latest_charge_amount` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `gco_total_charge_amount` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `gco_latest_chargeback_amount` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `gco_total_chargeback_amount` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci ,
ADD `gco_total_refund_amount` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `gco_latest_refund_amount` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `lead_source` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `referring_url` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `locale` VARCHAR(6) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `currency_locale` VARCHAR(6) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `txtype` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `cart` BLOB;

And run these to allow for temporary order numbers of greater than the default 14 character field type
ALTER TABLE `transactions` MODIFY `order_number` varchar(32);
ALTER TABLE `orderline` MODIFY `order_number` varchar(32);


In etc/log_transction, immediately after the
[elsif variable MV_PAYMENT_MODE]
	[calc]
insert this line:
	undef $Session->{payment_result}{MStatus};

and leave
[elsif variable MV_PAYMENT_MODE]
as set (contrary to earlier revisions of this document), but within the same section change the following 
two instances of
[var MV_PAYMENT_MODE] to [value mv_payment_route]

Also add these five lines to the end of the section that starts "[import table=transactions ":
lead_source: [data session source]
referring_url: [data session referer]
locale: [scratch mv_locale]
currency_locale: [scratch mv_currency]
cart: [calc]uneval($Items)[/calc]
for use when sending the merchant report and customer receipt emails out. 

Still in etc/log_transaction, find the section that starts "Set order number in values: " and insert
this just before it:
[if value mv_order_profile =~ /googlecheckout/]
[value name=mv_order_number set="[scratch purchaseID]" scratch=1]
[else]
and a closing [/else][/if] at the end of that section, just before the 
"Set order number in session:"
line. The order number is generated by the module and passed to Google at an early stage, and then
passed back to Interchange at a later stage. This prevents Interchange generating another order number.
If your Interchange installation is 5.2.0 or older this line will not exist - set oldic to '1' in 
the payment route and allow Interchange to generate the order number instead. Note: the initial order number
uses the username.counter number prefixed with 'GCOtmp', and a normal order number is created and the initial order number
replaced only when Google reports that the card has been charged. This is to avoid gaps in the order
number sequence caused by customers abandoning the transaction while at Google.

=over

=item Failed atttempts to authorise or charge the buyer's card.
If the card is declined by the bank then IC will be updated with the new status and a brief email sent
to the buyer telling him of the fact, and asking him to try another payment method.


=item AVS and CV2 risk assessment:
avs_match_accepted partial|full|none

AVS options and returned values are these:
Y - Full AVS match (address and postal code)
P - Partial AVS match (postal code only)
A - Partial AVS match (address only)
N - no AVS match
U - AVS not supported by issuer
If the route is set to 'full' then, unless AVS is not supported (eg in cards foreign to the country
doing the processing), a full match is required. Set to 'partial' (the default) for partial match, or
'none' for no match required.

CV2 values:
cv2_match_accepted  yes|none
M - CVN match
N - No CVN match
U - CVN not available
E - CVN error
If the route is set to 'yes' then the CV2 must match unless it is not available. If set to 'none' then
a match is not required. Default is 'yes'.

Both of these must be positive according to your rules for the transaction to be charged - if not positive
then the transaction will be refused and a brief email sent to the prospective buyer to say so.


=item Google Analytics

This page: http://code.google.com/apis/checkout/developer/checkout_analytics_integration.html will tell
you how to integrate Analytics into the system. This module will pass the data as an 'analyticsdata' 
value from the checkout form, encoded as UTF-8. 


=item Error messages from GCO

GCO will send error messages with a '<' in the title, which Interchange interprets as a possible attack
and so immediately stops reading the page and throws the user to the 'violation' page (defined in your
catalog.cfg as 'SpecialPage ../special_pages/violation' normally, though may be different).
Insert the following at the top of that page, which will test for the string sent by Google and then
bounce the user back to the checkout page with a suitable error message. This uses the 'env' UserTag.

[tmp uri][env REQUEST_URI][/tmp]
 [if  type=explicit compare=`$Scratch->{uri} =~ /%20400%20Bad%20Request%3C\?xml/`]
[perl]
 	$msg = errmsg("GoogleCheckout has encountered an error - if all of your address and shipping entries are correct, please consider using our 'Credit Card Checkout' instead. Our apologies for any inconvenience.");
	$::Session->{errors}{GoogleCheckout} = $msg;
[/perl]
 [bounce href="[area ord/checkout]"]
 [/if]

=back

=head1 Bugs

The default CharSet.pm in Interchange 5.6 (and possibly earlier) will fail on GCO's notifications. The
sympton is that GCO keeps repeating the 'new order notification' as though it has not received one, but
does not return any errors. Set a variable in your catalog.cfg, thus: 
Variable	MV_HTTP_CHARSET	UTF-8
but  be aware that this may break the display of some upper ASCII characters, eg the GBP £ sign (use &pound; instead of £)

=head1 Changelog

v.0.7.0, 29.01.2009
	- added locale, currency_locale, and cart fields to transaction tbl
	- log basket to transaction tbl to be read and inserted back into session for final order route
	- altered main 'googlecheckout' order route and added new 'gco_final' order route. Replaced previous
	  method of sending emails with this final route. 
	- added failsafe logging prior to going to Google, in orders/gco/, file name is 'date.session_id'
	
v 0.7.1, May 2009.
	- changed order number creation to only come after Google reports the card as charged. Initially
	  uses the tid (from tid.counter) as a temporary order number.

v0.7.2, May 2009,
	- updated documentation, simplifed system for co-operating with other payment systems. 

v0.7.3, June 2009
	- added code to update userdb, decrement inventory table and add more meaningful order subject (thanks to Andy Smith of tvcables.co.uk)
	- also fixed an error whereby KDE's Kate had fooled me with incorrect bracket matching.
		
=cut

BEGIN {
	my $selected;
		eval {
			package Vend::Payment;
			require XML::Simple;
			require LWP;
			require MIME::Base64;
			require HTTP::Request::Common;
			import HTTP::Request::Common qw(POST);
			require Net::SSLeay;
			require HTML::Entities;
			require Encode;
			import Encode qw(encode decode);
			require Data::Dumper;
			$selected = "XML::Simple and MIME::Base64";
		};

		$Vend::Payment::Have_Google = 1 unless $@;

	unless ($Vend::Payment::Have_Google) {
		die __PACKAGE__ . " requires XML::Simple, MIME::Base64";
	}

use XML::Simple;

::logGlobal("%s v0.7.3 payment module initialised, using %s", __PACKAGE__, $selected) unless $Vend::Quiet;

}

package Vend::Payment;
use strict;
my ($gcourl,$merchantid,$merchantkey,$gcoserver,$xmlOut, $taxrate, $state, $header, $gcorequest, $actual, $orderID);

sub googlecheckout {
	my ($opt, $purchaseID, $mv_order_number, $msg, $cart, %result);
       $gcoserver   = charge_param('googlehost')  || $::Variable->{MV_PAYMENT_HOST} || 'https://checkout.google.com/api/checkout/v2'; # live
	my $catroot     = charge_param('cat_root') || $::Variable->{CAT_ROOT};
	my $ordersdir   = charge_param('ordersdir') || 'orders';
	my $currency    = $::Values->{currency} || charge_param('currency') || 'GBP';	
	my $editbasketurl = charge_param('edit_basket_url') || $::Variable->{EDIT_BASKET_URL};
	   $editbasketurl =~ s/\.html$//i;
       $editbasketurl .= ".html?id=$::Session->{id}";
	my $continueshoppingurl = charge_param('continue_shopping_url') || $::Variable->{CONTINUE_SHOPPING_URL};
	my $receipturl  = charge_param('receipt_url') || $::Variable->{RECEIPT_URL};
	my $gcoipn_url  = charge_param('gcoipn_url') || $::Variable->{GCOIPN_URL};
	my $gcocmd_url  = charge_param('gcocmd_url') || $::Variable->{GCOCMD_URL}; # from IC admin panel, not from GCO
	my $chargecard  = $::Values->{charge_card} || charge_param('charge_card') || '1';
	my $basket_expiry = charge_param('basket_expiry') || $::Variable->{BASKET_EXPIRY} || '1 month';
	my $default_taxrate = $::Values->{default_taxrate} || charge_param('default_taxrate') || '0.00';
	my $reduced_taxrate = $::Values->{reduced_taxrate} || charge_param('reduced_taxrate') || '0.00';
	my $taxratefield     = charge_param('taxrate_field') || 'taxrate';
	my $reduced_taxfield = charge_param('reduced_tax_field') || 'reduced';
	my $exempt_taxfield = charge_param('exempt_tax_field') || 'exempt';
	my $tax_included = $::Values->{tax_included} || charge_param('tax_included') || '';
	my $calculate_included_tax = $::Values->{calculate_included_tax} || charge_param('calculate_included_tax') || '';
	my $ordernumber  = charge_param('ordernumber') || 'etc/order.number';
	my $gcocounter   = charge_param('gcocounter') || 'etc/username.counter'; 
	my $defaultshipmode = charge_param('default_shipmode') || 'upsg';
	my $defaultcountry  = $::Values->{default_country} || charge_param('default_country') || '';
	my $defaultstate    = $::Values->{default_state} || charge_param('default_state') || '';
	my $bypass_auth  = charge_param('bypass_authorization') || '1';
	my $senderemail  = charge_param('sender_email') ;
	my $merchantemail = charge_param('merchant_email') || $::Variable->{ORDERS_TO};
	my $doreceipt    = charge_param('receipt_from_merchant') || '1';
	my $sendemail    = charge_param('email_auth_charge') || 'charge';
	my $htmlmail     = charge_param('html_mail') || '';
	my $mailriskfail = $::Values->{mailriskfail} || charge_param('mail_on_risk_failure') || "Authentication checks failed";
	my $gcocmd       = $::Values->{gcocmd} || '';
	my $avsmatch     = charge_param('avs_match_accepted') || 'partial';
	my $cv2match     = charge_param('cv2_match_accepted') || 'yes';
	my $checkouturl  = charge_param('checkouturl') || "$::Variable->{SECURE_SERVER}$::Variable->{CGI_URL}/ord/checkout";
	my $returnurl    = charge_param('returnurl')   || "$::Variable->{SECURE_SERVER}$::Variable->{CGI_URL}/ord/gcoreceipt";
	   $returnurl    =~ s/\.html$//i;
	   $returnurl   .= ".html?id=$::Session->{id}";
	my $diagnose     = $::Values->{gco_diagnose} || charge_param('gco_diagnose') || ''; # set to '1' to have GCO return the XML it receives for diagnostics
	my $analytics_data = $::Values->{analyticsdata} || '';
	      $analytics_data = encode('UTF-8', $analytics_data);
	my $tracking       = charge_param('tracking_script') || ''; 
	my $without_address = charge_param('without_address') || ''; 
	my $reporttitle = charge_param('reporttitle') || ''; 
	my $dec_inventory = charge_param('decrement_inventory') || ''; # set to 1 to decrement inventory upon successful 'charge'
	my $alwaystaxshipping = charge_param('alwaystaxshipping') || ''; # set to 1 to always tax shipping despite other config options

#----------------------------------------------------------------------------------------
       $merchantid  = charge_param('merchantid')  || $::Variable->{MV_PAYMENT_ID};
       $merchantkey = charge_param('merchantkey') || $::Variable->{MV_PAYMENT_SECRET};
       $gcorequest  = charge_param('gcorequest')  || $::Values->{gcorequest} || 'post';
	   $::Values->{gcorequest} = '';
			
	if ($gcorequest eq 'post') {
		$gcourl = "$gcoserver/merchantCheckout/Merchant/$merchantid";
	      }
	else {
		$gcourl = "$gcoserver/request/Merchant/$merchantid";
	}
    
	$gcourl .= "/diagnose" if ($diagnose == '1');
#::logDebug(":GCO:".__LINE__.": gcourl=$gcourl");

my $gco = new(
                  merchant_id        => $merchantid,
                  merchant_key       => $merchantkey,
                  gco_server         => $gcourl,
                  currency_supported => $currency
             );

my (%actual) = map_actual();
	$actual  = \%actual;
	$opt     = {};
#::logDebug(":GCO:".__LINE__." actual map result: " . ::uneval($actual));

#----------------------------------------------------------------------------------------
# Initial post to GCO
#----------------------------------------------------------------------------------------
if ($gcorequest eq 'post') {
   undef $gcorequest;
	my $salestax = $::Values->{tax} || Vend::Interpolate::salestax() || '0.00';
	my $shipmode = $::Values->{mv_shipmode} || charge_param('default_shipmode') || 'upsg';
	my $shipping = $::Session->{final_shipping} || Vend::Ship::shipping($shipmode) || charge_param('default_shipping') || '0.00';
	my $handling = $::Values->{handlingtotal} || Vend::Ship::tag_handling() || '';
       $shipping += $handling;
	my $shipmsg  = $::Session->{ship_message};
	my $subtotal = $::Values->{amount} || Vend::Interpolate::subtotal();
	my $ordertotal = charge_param('amount') || Vend::Interpolate::total_cost();
print "GCO".__LINE__.": tax=$salestax; shipping=$shipping, $::Values->{mv_shipping}; shipmode=$shipmode\n";
	my $defaultcountry = charge_param('defaultcountry');
	my $defaultstate = charge_param('defaultstate');
	my $country  = uc($actual->{country});
              $country  = $defaultcountry unless $country; 
	my $state    = uc($actual->{state});
              $state    = $defaultstate unless $state;
	my $zip_pattern = $actual->{zip} || $::Values->{zip};
              $zip_pattern =~ /(\S\S\S).*/;
              $zip_pattern = "$1"."*";
    my $taxshipping = 'false';
              $taxshipping = 'true' if (($country =~ /$::Variable->{TAXSHIPPING}/) or ($state =~ /$::Variable->{TAXSHIPPING}/) or ($alwaystaxshipping == '1'));
::logDebug(":GCO:".__LINE__.": shipping=$::Session->{final_shipping}, $shipping; handling=$handling; taxshipping=$::Variable->{TAXSHIPPING}; country=$country; tx=$taxshipping");
 my $stax = Vend::Interpolate::salestax();
 print "GCO:".__LINE__.": stax=$stax; mvst=$::Values->{mv_salestax}, $::Values->{salestax}\n";
if ($salestax == '0') { 
         $taxrate = '0.00';
          }
  elsif ($taxshipping eq 'true') { 
         $taxrate = ($salestax / ($subtotal + $shipping) || '0');
          }
  elsif ($calculate_included_tax == '1') {
         $taxrate = $default_taxrate;
          } 
  else { 
         $taxrate =  ($salestax / $subtotal || '0');
}
::logDebug(":GCO:".__LINE__.": subtotal=$subtotal; taxrate=$taxrate");

### Check that the currency sent to GCO is the one registered with them, or return to the checkout
my $user_currency = $::Scratch->{iso_currency_code} || $::Values->{iso_currency_code} || $currency;
#::logDebug(" ".__LINE__.": user currency = $user_currency, $::Scratch->{iso_currency_code}, $::Values->{iso_currency_code}; currency=$currency"); 
 if ($user_currency ne $currency) {
	$msg = errmsg("GoogleCheckout can take only $currency, so please reset the currency option on the page to $currency. Thank you");
	$::Session->{errors}{GoogleCheckout} = $msg;
 return();
}

#::logDebug(":GCO:".__LINE__.": ordertot=$ordertotal; subtot=$subtotal; amount=$::Values->{amount}; tax=$::Values->{tax} - $salestax; invno=$::Values->{inv_no}; zip=$zip_pattern; country=$country");

my ($item, $itm, $basket);
if (($::Values->{inv_no}) or ($::Values->{digital_delivery})) {
  $shipmode = 'Digital';
  $basket = <<EOX;
   <item>
    <merchant-item-id>$::Values->{inv_no}</merchant-item-id>
	<item-name>$::Values->{inv_no}</item-name>
	<item-description>$::Values->{notes}</item-description>
	 <quantity>1</quantity>
	<unit-price currency="$currency">$subtotal</unit-price>
   </item>
EOX
   }
# TODO: allow for carts other than 'main'
elsif ($::Carts->{'main'}) {
	foreach  $item (@{$::Carts->{'main'}}) {
	    $itm = {
	    		code         => $item->{'code'},
				quantity     => $item->{'quantity'},
				tax_category => Vend::Data::item_field($item,'tax_category'),
				taxrate      => Vend::Data::item_field($item,$taxrate),
				description  => Vend::Data::item_description($item),
				price        => Vend::Data::item_price($item)
				};
   if ($itm->{code}){
# Trailing white space, raw & < > are all 'invalid xml'.
       $itm->{code} =~ s/\s*$//g;
       $itm->{code} =~ s/&/&#x26;/g;
       $itm->{code} =~ s/</&#x3c;/g;
       $itm->{code} =~ s/>/&#x3e;/g;
       $itm->{description} =~ s/\s*$//g;
       $itm->{description} =~ s/&\s/and /g;
       $itm->{description} = HTML::Entities::encode_entities($itm->{description});
       $itm->{price} =~ s/\s*$//g;
       $itm->{price} /= (1 + ($itm->{taxrate} || $default_taxrate)) 
       				if ($calculate_included_tax == '1');
       $itm->{quantity} =~ s/\s*$//g;
  
  if ($itm->{tax_category}) {
  $basket .= <<EOB;
   <item>
    <merchant-item-id>$itm->{code}</merchant-item-id>
	<item-name>$itm->{code}</item-name>
	<item-description>$itm->{description}</item-description>
	<unit-price currency="$currency">$itm->{price}</unit-price>
    <quantity>$itm->{quantity}</quantity>
    <tax-table-selector>$itm->{tax_category}</tax-table-selector>
   </item>
EOB
        }
  else {
  $basket .= <<EOB;
   <item>
    <merchant-item-id>$itm->{code}</merchant-item-id>
	<item-name>$itm->{code}</item-name>
	<item-description>$itm->{description}</item-description>
	<unit-price currency="$currency">$itm->{price}</unit-price>
    <quantity>$itm->{quantity}</quantity>
   </item>
EOB
      }
	 }
   }
 }
else {
  $msg = errmsg("You must pass something to GoogleCheckout");
	$::Session->{errors}{GoogleCheckout} = $msg;
	return($msg);
}

   $orderID = gen_order_id($opt);
   $::Scratch->{orderID} = $orderID;
   $::Scratch->{txtype} = 'GCO - PENDING';

# Disable order number creation in log_transaction and create it here instead
if ($::Values->{inv_no}) {
   $purchaseID = $::Values->{inv_no};
      }
elsif ($::Values->{mv_order_number}){
  # IC 5.2 and earlier set order number prior to log_transaction
   $purchaseID = $::Values->{mv_order_number};
      }
else{
# Use temporary number as the initial order number, and only replace upon successful order completion
    $purchaseID = 'GCOtmp'.Vend::Interpolate::tag_counter("$gcocounter");
#::logDebug(":GCO:".__LINE__.": purchaseID=$purchaseID;");
}
    
    $::Scratch->{purchaseID} = $purchaseID;

#::logDebug(":GCO:".__LINE__.": txtype=$::Scratch->{txtype};  orderid=$orderID, purchaseid=$purchaseID");

# XML to send
$xmlOut = <<EOX;
<?xml version="1.0" encoding="UTF-8"?>
<checkout-shopping-cart xmlns="http://checkout.google.com/schema/2">
 <shopping-cart>
  <merchant-private-data>
   <merchant-note>$purchaseID</merchant-note>
  </merchant-private-data>
   <items>
EOX

  $xmlOut .= $basket;

  $xmlOut .= <<EOX;
   </items>
 </shopping-cart>
<checkout-flow-support>
<merchant-checkout-flow-support>
 <edit-cart-url>$editbasketurl</edit-cart-url>
  <continue-shopping-url>$continueshoppingurl</continue-shopping-url>
   <tax-tables>
	<default-tax-table>
	 <tax-rules>
	  <default-tax-rule>
	  <shipping-taxed>$taxshipping</shipping-taxed>
	  <rate>$taxrate</rate>
	  <tax-area>
EOX

if ($country =~ /US/i) {
 $xmlOut .= <<EOX;
 	 	<us-state-area>
 	 	 <state>$state</state>
 	 	</us-state-area>
EOX
   }
else {
  $xmlOut .= <<EOX;
        <postal-area>
         <country-code>$country</country-code>
        </postal-area>
EOX
 }

 $xmlOut .= <<EOX;
	   </tax-area>
	  </default-tax-rule>
	 </tax-rules>
	</default-tax-table>
    <alternate-tax-tables>
     <alternate-tax-table standalone="true" name="$reduced_taxfield">
       <alternate-tax-rules>
         <alternate-tax-rule>
           <rate>$reduced_taxrate</rate>
           <tax-area>
             <world-area/>
           </tax-area>
         </alternate-tax-rule>
       </alternate-tax-rules>
     </alternate-tax-table>
     <alternate-tax-table standalone="true" name="$exempt_taxfield">
       <alternate-tax-rules/>
     </alternate-tax-table>
   </alternate-tax-tables>
  </tax-tables>
<shipping-methods>
 <flat-rate-shipping name="$shipmode">
  <price currency="$currency">$shipping</price>
   <shipping-restrictions>
	<allowed-areas>
EOX

if ($country =~ /US/i) {
 $xmlOut .= <<EOX;
        <us-state-area>
      	  <state>$state</state>
	    </us-state-area>
		<us-zip-area>
          <zip-pattern>$zip_pattern</zip-pattern>
        </us-zip-area>
EOX
    }
else {
  $xmlOut .= <<EOX;
	 <postal-area>
	  <country-code>$country</country-code>
	   <postal-code-pattern>$zip_pattern</postal-code-pattern>
	 </postal-area>
EOX
 }
  $xmlOut .= <<EOX;
	</allowed-areas>
   </shipping-restrictions>
 </flat-rate-shipping>
</shipping-methods>
 <analytics-data>$analytics_data</analytics-data>
  <parameterized-urls>
    <parameterized-url url="$returnurl"/>
  </parameterized-urls>
</merchant-checkout-flow-support>
</checkout-flow-support>
</checkout-shopping-cart>
EOX

#
# Write full order to orders/gco/ using gco$date.$session_id file name as failsafe backup in case order 
# route fails. 

	my $date     = $Tag->time({ body => "%Y%m%d%H%M%S" });
	my $pagefile = charge_param('report_page') || 'etc/report';
	my $page     = readfile($pagefile);
	   $page     = interpolate_html($page) if $page;

	mkdir "$ordersdir/gco", 0775 unless -d "$ordersdir/gco";
	
	my $fn = Vend::Util::catfile(
				"$ordersdir/gco",
				"gco$date.$::Session->{id}"  
			);
   
    Vend::Util::writefile( $fn, $page )
				or ::logError("GCO error writing failsafe order $fn: $!");
	
#--------------------------------------------------------------------------------
# Post the basket to GCO and read the redirect URL to which the customer is sent.
   my $return = sendxml($xmlOut);
   my $xml    = new XML::Simple();
   my $xmlin  = $xml->XMLin("$return");
	  $::Session->{errors}{GoogleCheckout} = $xmlin->{'error-message'}
				if $xmlin->{'error-message'};
 
    my $redirecturl = $xmlin->{'redirect-url'};
	my $gco_serial_number = $xmlin->{'serial-number'};
#::logDebug(":GCO:".__LINE__.": return=$return, redirect=$redirecturl; gcourl=$gcourl;serial number=$gco_serial_number");
use Data::Dumper; # for debugging
# print Dumper($xmlin); # for debugging
#print Dumper($::Session);  
  unless (($xmlin->{'error-message'}) or ($diagnose)) {
	  $redirecturl = Vend::Util::header_data_scrub($redirecturl);

$::Tag->tag({ op => 'header', body => <<EOB });
Status: 302 moved
Location: $redirecturl
EOB


# Fake the result so that IC can log the transaction
   $result{Status}     = 'success';
   $result{MStatus}    = 'success';
   $result{'order-id'} = $orderID;
   
   return %result;
      }
 
 }

#----------------------------------------------------------------------------------------
# Now handle callbacks, eg notification of payment, risk assessment, etc
#----------------------------------------------------------------------------------------

	elsif ($gcorequest eq 'callback') {

#### First authenticate the message using the merchantid and merchantkey in the header, then
#### determine type of callback and respond appropriately.  Apache does not pass HTTP_AUTHORIZATION to
#### the environment in its default configuration for security reasons, and may need to be recompiled

	my $authdata = $ENV{HTTP_AUTHORIZATION};
	my ($id, $key, $authed, $email, $locale, $company_name, $new_order_no, $date, $phone, $sendermail);

  unless ($bypass_auth == '1') {
	 if (($authdata) and (substr($ENV{HTTP_AUTHORIZATION},0,6) eq 'Basic ')) {
        my $decoded = decode_base64(substr($ENV{HTTP_AUTHORIZATION},6));
           if ($decoded =~ /:/) {
              ($id, $key) = split(/:/, $decoded);
           		if (($id eq $merchantid) and ($key eq $merchantkey)) {
                	$authed = 'yes';
        		      	}
			    else {
         			$authed = 'failed';
		        }
    	   }
  	  }
  }

if (($authed eq 'yes') or ($bypass_auth == '1')) {

# Read xml, initialise db table, create new XML object.
 	my $xmlIpn = ::http()->{entity};
# ::logDebug(":GCO:".__LINE__.": xmlIpn=$$xmlIpn");
	my $db  = dbref('transactions') or die errmsg("cannot open transactions table");
	my $dbh = $db->dbh() or die errmsg("cannot get handle for tbl 'transactions'");
    my $sth;
    
    my $xml   = new XML::Simple();
    my $xmlin = $xml->XMLin("$$xmlIpn");
	my $gco_serial_number = $xmlin->{'serial-number'};

#--- new order notification ---------------------------------------------------------------
if ($$xmlIpn =~ /new-order-notification/) {
	my $gco_order_number      = $xmlin->{'google-order-number'}; 
	my $gco_timestamp         = $xmlin->{'timestamp'}; 	
	my $gco_fulfillment_state = $xmlin->{'fulfillment-order-state'}; 
	my $gco_financial_state   = $xmlin->{'financial-order-state'}; 	
	my $email_allowed         = $xmlin->{'buyer-marketing-preferences'}->{'email-allowed'}; 
	my $buyers_id             = $xmlin->{'buyer-id'}; 
	my $total_tax             = $xmlin->{'order-adjustment'}->{'total-tax'}->{'content'}; 
	my $shipping              = $xmlin->{'order-adjustment'}->{'shipping'}->{'flat-rate-shipping-adjustment'}->{'shipping-cost'}->{'content'}; 
	my $order_total           = $xmlin->{'order-total'}->{'content'}; 
	my $mv_order_number       = $xmlin->{'shopping-cart'}->{'merchant-private-data'}->{'merchant-note'};
	my $company_name          = $xmlin->{'buyer-shipping-address'}->{'company-name'}
	                               unless ($xmlin->{'buyer-shipping-address'}->{'company-name'} =~ /HASH/);
	my $buyers_name           = $xmlin->{'buyer-shipping-address'}->{'contact-name'};
	my $fname                 = $xmlin->{'buyer-shipping-address'}->{'structured-name'}->{'first-name'};
	my $lname                 = $xmlin->{'buyer-shipping-address'}->{'structured-name'}->{'last-name'};
	my $address1              = $xmlin->{'buyer-shipping-address'}->{'address1'};
	my $address2              = $xmlin->{'buyer-shipping-address'}->{'address2'}
	                               unless ($xmlin->{'buyer-shipping-address'}->{'address2'} =~ /HASH/);
	my $city                  = $xmlin->{'buyer-shipping-address'}->{'city'};
	my $state                 = $xmlin->{'buyer-shipping-address'}->{'region'}
	                               unless ($xmlin->{'buyer-shipping-address'}->{'region'} =~ /HASH/);
	my $postal_code           = $xmlin->{'buyer-shipping-address'}->{'postal-code'}
	                               unless ($xmlin->{'buyer-shipping-address'}->{'postal-code'} =~ /HASH/);
	my $country               = $xmlin->{'buyer-shipping-address'}->{'country-code'};
	my $phone                 = $xmlin->{'buyer-shipping-address'}->{'phone'}
	                               unless ($xmlin->{'buyer-shipping-address'}->{'phone'} =~ /HASH/);
	my $fax                   = $xmlin->{'buyer-shipping-address'}->{'fax'}
	                               unless ($xmlin->{'buyer-shipping-address'}->{'fax'} =~ /HASH/);
	my $email                 = $xmlin->{'buyer-shipping-address'}->{'email'};
	my $b_company_name        = $xmlin->{'buyer-billing-address'}->{'company-name'}
	                               unless ($xmlin->{'buyer-billing-address'}->{'company-name'} =~ /HASH/);
	my $b_buyers_name         = $xmlin->{'buyer-billing-address'}->{'contact-name'};
	my $b_fname               = $xmlin->{'buyer-billing-address'}->{'structured-name'}->{'first-name'};
	my $b_lname               = $xmlin->{'buyer-billing-address'}->{'structured-name'}->{'last-name'};
	my $b_address1            = $xmlin->{'buyer-billing-address'}->{'address1'};
	my $b_address2            = $xmlin->{'buyer-billing-address'}->{'address2'}
	                               unless ($xmlin->{'buyer-billing-address'}->{'address2'} =~ /HASH/);
	my $b_city                = $xmlin->{'buyer-billing-address'}->{'city'};
	my $b_state               = $xmlin->{'buyer-billing-address'}->{'region'}
	                               unless ($xmlin->{'buyer-billing-address'}->{'region'} =~ /HASH/);
	my $b_postal_code         = $xmlin->{'buyer-billing-address'}->{'postal-code'}
	                               unless ($xmlin->{'buyer-billing-address'}->{'postal-code'} =~ /HASH/);
	my $b_country             = $xmlin->{'buyer-billing-address'}->{'country-code'};
	my $b_phone               = $xmlin->{'buyer-billing-address'}->{'phone'}
	                               unless ($xmlin->{'buyer-billing-address'}->{'phone'} =~ /HASH/);

   	   $buyers_name =~ /(\w+)\s+(\D+)/;
	   $fname = $1 if ($fname =~ /HASH/);
	   $lname = $2 if ($lname =~ /HASH/);
   	   $b_buyers_name =~ /(\w+)\s+(\D+)/;
	   $b_fname = $1 if ($b_fname =~ /HASH/);
	   $b_lname = $2 if ($b_lname =~ /HASH/);
       
       $postal_code =~ /^(\S\S\S).*/;
    my $postal_code_short = $1;
 
#::logDebug(":GCO:".__LINE__.": gsn=$gco_serial_number, gon=$gco_order_number, shipping=$shipping,  fname=$fname, lname=$lname, mvon=$mv_order_number");
# Update IC db - update total_cost here as well, in case of penny differences in rounding methods.
	  $sth = $dbh->prepare("UPDATE transactions SET fname='$fname',lname='$lname',address1='$address1',address2='$address2',city='$city',state='$state',zip='$postal_code',country='$country',phone_day='$phone',fax='$fax',email='$email',company='$company_name', b_fname='$fname',b_lname='$lname',b_address1='$address1',b_address2='$address2',b_city='$city',b_state='$state',b_zip='$postal_code',b_country='$country',b_phone='$phone',b_company='$company_name',total_cost='$order_total', salestax='$total_tax',shipping='$shipping', gco_order_number='$gco_order_number',txtype='GCO - $gco_financial_state',gco_fulfillment_state='$gco_fulfillment_state',gco_serial_number='$gco_serial_number',gco_buyers_id='$buyers_id',gco_timestamp='$gco_timestamp' WHERE order_number='$mv_order_number'");
      $sth->execute() or die errmsg("Cannot update transactions tbl for gco '$mv_order_number'");
    
    }

#--- update to order ---------------------------------------------------------------------------------------
elsif ($$xmlIpn =~ /order-state-change-notification/) {
	my $gco_serial_number     = $xmlin->{'serial-number'};
	my $gco_order_number      = $xmlin->{'google-order-number'}; 
	my $gco_timestamp         = $xmlin->{'timestamp'}; 
	my $gco_fulfillment_state = $xmlin->{'new-fulfillment-order-state'}; 
	my $gco_financial_state   = $xmlin->{'new-financial-order-state'}; 
	
	   $sth = $dbh->prepare("SELECT total_cost,email,txtype,order_number FROM transactions WHERE gco_order_number='$gco_order_number'") or die errmsg("Cannot select from transactions tbl for $gco_order_number");
       $sth->execute() or die errmsg("Cannot get data from transactions tbl");
    my @d = $sth->fetchrow_array;
    my $order_total = $d[0];
       $email       = $d[1];
    my $txtype      = $d[2];
    my $old_tid     = $d[3];

	unless ($txtype =~ /GCO - CHARGED/i) {
	   if ($gco_financial_state =~ /CHARGED/i) {
	      $new_order_no  = Vend::Interpolate::tag_counter("$ordernumber") unless defined $::Values->{mv_order_number}; 
		  $sth = $dbh->prepare("UPDATE transactions SET code='$new_order_no', order_number='$new_order_no', txtype='GCO - $gco_financial_state',gco_fulfillment_state='$gco_fulfillment_state',gco_timestamp='$gco_timestamp' WHERE gco_order_number='$gco_order_number'");
	   my $stho = $dbh->prepare("UPDATE orderline SET status='processing', code=replace(code, '$old_tid', '$new_order_no'), order_number='$new_order_no' WHERE order_number='$old_tid'");
		  $stho->execute() or die errmsg("Cannot update orderline tbl for gco '$gco_order_number'") unless defined $::Values->{mv_order_number};
	# Decrement inventory here now that we know the transaction has succeeded
	   if ($dec_inventory == '1') {
		my $sthcart = $dbh->prepare("SELECT cart FROM transactions WHERE gco_order_number='$gco_order_number'") or die errmsg("Cannot select from transactions tbl for $gco_order_number");
		   $sthcart->execute() or die errmsg("Cannot get data from transactions tbl");
		my $cart = $sthcart->fetchrow_array;
	 		$cart = eval ($cart);
		my $dbi = dbref('inventory') or die errmsg("cannot open inventory table");
		my $dbhi = $dbi->dbh() or die errmsg("cannot get handle for tbl 'inventory'");
		my ($sthi, $itm, $qty);

	foreach my $items (@{$cart}) { 
					$itm = $items->{'code'};
					$qty = $items->{'quantity'};
					$sthi = $dbh->prepare("UPDATE inventory SET quantity = quantity -'$qty' WHERE sku = '$itm'");
					$sthi->execute() or die errmsg("Cannot update table inventory");
::logDebug(":GCO:".__LINE__.": Decremented inventory for $itm by $qty");
					}
				  }	
	   			}
	   	else {
       $sth = $dbh->prepare("UPDATE transactions SET txtype='GCO - $gco_financial_state', gco_fulfillment_state='$gco_fulfillment_state',gco_timestamp='$gco_timestamp' WHERE gco_order_number='$gco_order_number'");
       		}
       $sth->execute() or die errmsg("Cannot update transactions tbl for gco '$gco_order_number'") unless defined $::Values->{mv_order_number};
#::logDebug(":GCO:".__LINE__.": gco_finstate=$gco_financial_state; txtype=$txtype; neworderno=$new_order_no; pID=$purchaseID");	   
       }

	my ($mailout, $finstatus);

	if ($gco_financial_state =~ /PAYMENT_DECLINED/i) {
        $mailout = <<EOM;
Card payment for Google Order number $gco_order_number from $::Variable->{COMPANY}, $order_total, was
declined by your bank. Please use an alternative means of payment if you wish to proceed with this order.
EOM
  	$finstatus = "declined by your bank";
  	}
	elsif ($gco_financial_state =~ /CANCELLED/i) {
  		$mailout = <<EOM;
Google Order number $gco_order_number from $::Variable->{COMPANY} has been cancelled.
EOM
  	$finstatus = "cancelled";
  	}

	if ($gco_financial_state =~ /PAYMENT_DECLINED|CANCELLED/i) {
        $::Tag->email({ to => "$email", from => "$senderemail", reply => "$senderemail", extra => "Bcc: $merchantemail",
                subject => "Google order $gco_order_number has been $finstatus",
                body => "$mailout\n"
             });
        }
  }


#--- risk notification ---------------------------------------------------------------------------------------
elsif ($$xmlIpn =~ /risk-information-notification/) {
	my $gco_serial_number = $xmlin->{'serial-number'};
	my $gco_order_number  = $xmlin->{'google-order-number'}; 
	my $gco_timestamp     = $xmlin->{'timestamp'}; 
	my $gco_protection    = $xmlin->{'risk-information'}->{'eligible-for-protection'};
	my $gco_avs_response  = $xmlin->{'risk-information'}->{'avs-response'};
	my $gco_cvn_response  = $xmlin->{'risk-information'}->{'cvn-response'};	
	my $gco_cc_number     = $xmlin->{'risk-information'}->{'partial-cc-number'};
	my $gco_account_age   = $xmlin->{'risk-information'}->{'buyer-account-age'};
	my $gco_buyers_ip     = $xmlin->{'risk-information'}->{'ip-address'};

	   $sth = $dbh->prepare("UPDATE transactions SET gco_avs_response='$gco_avs_response',gco_cvn_response='$gco_cvn_response',gco_protection='$gco_protection',gco_cc_number='$gco_cc_number', gco_timestamp='$gco_timestamp' WHERE gco_order_number='$gco_order_number'");
       $sth->execute() or die errmsg("Cannot update transactions tbl for gco '$gco_order_number'");

# Assess risk, and if OK then optionally tell GCO to charge the card; and send out emails.
    my ($process_order, $avs, $cv2);
  if (($avsmatch) eq 'full' and ($gco_avs_response =~ /Y|U/i)) {
   		$avs = 'pass';
   		}
	elsif (($avsmatch) eq 'partial' and ($gco_avs_response !~ /N/i)) {
   		$avs = 'pass';
 		}
	elsif ($avsmatch eq 'none') {
   		$avs = 'pass';
   }

  if (($cv2match) eq 'yes' and ($gco_cvn_response !~ /N/i)) {
   		$cv2 = 'pass';
 		}
	elsif ($cv2match eq 'none') {
   		$cv2 = 'pass';
  }
 
  if (($avs eq 'pass') and ($cv2 eq 'pass')) {
   		if ($chargecard =~ /1|y/) { 
    # Tell Google to charge the card
       $sth = $dbh->prepare("SELECT total_cost FROM transactions WHERE gco_order_number='$gco_order_number'") or die errmsg("Cannot select from transactions tbl for $gco_order_number");
       $sth->execute() or die errmsg("Cannot get data from transactions tbl");
    my $order_total = $sth->fetchrow();

    my $xmlOut = <<EOX;
<?xml version="1.0" encoding="UTF-8"?>
<charge-order xmlns="http://checkout.google.com/schema/2" google-order-number="$gco_order_number">
    <amount currency="$currency">$order_total</amount>
</charge-order>
EOX
	 sendxml($xmlOut) ;
    		}
        }
 else  {
# Risk assessment fails to meet rules
  	   $::Tag->email({ to => "$email", from => "$senderemail", reply => "$sendermail", extra => "Bcc: $merchantemail",
                subject => "Google order $gco_order_number declined\n\n",
                body => "$mailriskfail\n"
             });
        }
    }

#--- charge amount ----------------------------------------------------------------------------------------
elsif ($$xmlIpn =~ /charge-amount-notification/) {
	my $gco_serial_number        = $xmlin->{'serial-number'};
	my $gco_order_number         = $xmlin->{'google-order-number'}; 
	my $gco_timestamp            = $xmlin->{'timestamp'}; 
	my $gco_latest_charge_amount = $xmlin->{'latest-charge-amount'}->{'content'};
	my $gco_total_charge_amount  = $xmlin->{'total-charge-amount'}->{'content'};

       $sth = $dbh->prepare("SELECT total_cost,email,order_number,fname,lname,company,address1,address2,city,state,zip,country,phone_day,fax,b_fname,b_lname,b_company,b_address1,b_address2,b_city,b_state,b_zip,b_country,shipmode,handling,subtotal,salestax,shipping,order_date,lead_source,referring_url,txtype,locale,currency_locale,cart,username FROM transactions WHERE gco_order_number='$gco_order_number'") or die errmsg("Cannot select from transactions tbl for $gco_order_number");
       $sth->execute() or die errmsg("Cannot get data from transactions tbl");
    my @d = $sth->fetchrow_array;
    my $order_total = $::Values->{order_total} = $d[0];
    my $email = $::Values->{email} = $d[1];
    my $mv_order_number = $::Values->{mv_order_number} = $d[2];
    my $fname = $::Values->{fname} = $d[3];
    my $lname = $::Values->{lname} = $d[4];
    my $company = $::Values->{company} = $d[5];
    my $address1 = $::Values->{address1} = $d[6];
    my $address2 = $::Values->{address2} = $d[7];
    my $city = $::Values->{city} = $d[8];
    my $state = $::Values->{state} = $d[9];
    my $zip = $::Values->{zip} = $d[10];
    my $country = $::Values->{country} = $d[11];
    my $phone_day = $::Values->{phone_day} = $d[12];
    my $fax = $::Values->{fax} = $d[13];
    my $b_fname = $::Values->{b_fname} = $d[14];
    my $b_lname = $::Values->{b_lname} = $d[15];
    my $b_company = $::Values->{b_company} = $d[16];
    my $b_address1 = $::Values->{b_address1} = $d[17];
    my $b_address2 = $::Values->{b_address2} = $d[18];
    my $b_city = $::Values->{b_city} = $d[19];
    my $b_state = $::Values->{b_state} = $d[20];
    my $b_zip = $::Values->{b_zip} = $d[21];
    my $b_country = $::Values->{b_country} = $d[22];
    my $shipmode = $::Values->{shipmode} = $d[23];
    my $handling = $::Values->{handling} = $d[24];
    my $subtotal = $::Values->{subtotal} = $d[25];
    my $salestax = $::Values->{salestax} = $d[26];
    my $shipping = $::Values->{shipping} = $d[27];
    my $order_date = $::Values->{order_date} = $d[28];
    my $lead_source = $::Session->{lead_source} = $d[29];
    my $referring_url = $::Session->{referer} = $d[30];
	my $txtype = $::Values->{txtype} = $d[31];
	my $mv_locale = $d[32];
	my $mv_currency = $d[33];
	my $cart = $d[34];
	my $username = $d[35];

		$cart =~ s/\"/\'/g;
		$cart =~ s/\\//;
		$cart = eval($cart); 
#::logDebug(":GCO:".__LINE__.": cart=$cart");	
	   
	   $::Values->{mv_payment} = 'GoogleCheckout';
	   $::Values->{gco_order_number} = $gco_order_number;
	   $::Session->{values}->{iso_currency_code} = $currency;
	   $::Session->{scratch}->{mv_locale} = $mv_locale;
	   $::Session->{scratch}->{mv_currency} = $mv_currency || $locale;
 
 # Check that the order has not already been charged, as Google sometimes send extra IPNs when they shouldn't.
	unless ($txtype =~ /GCO - CHARGED/i) {
 	   $sth = $dbh->prepare("UPDATE transactions SET order_number='$purchaseID', gco_latest_charge_amount='$gco_latest_charge_amount',gco_total_charge_amount='$gco_total_charge_amount',gco_timestamp='$gco_timestamp' WHERE gco_order_number='$gco_order_number'");
       $sth->execute() or die errmsg("Cannot update transactions tbl for gco '$gco_order_number'");
       }

# Update the customer's details in userdb
	  $db = dbref('userdb') or die errmsg("cannot open userdb table");
	  $dbh = $db->dbh() or die errmsg("cannot get handle for tbl 'userdb'");
	  $sth = $dbh->prepare("UPDATE userdb SET fname='$fname',lname='$lname',address1='$address1',address2='$address2',city='$city',state='$state',zip='$zip',country='$country',phone_day='$phone',fax='$fax',email='$email',company='$company_name' WHERE username='$username'");
	  $sth->execute() or die errmsg("Cannot update userdb tbl for user '$username'");

# Add IC order number to GCO admin panel
    my $xmlOut = <<EOX;
<?xml version="1.0" encoding="UTF-8"?>
<add-merchant-order-number xmlns="http://checkout.google.com/schema/2" google-order-number="$gco_order_number">
    <merchant-order-number>$mv_order_number</merchant-order-number>
</add-merchant-order-number>
EOX
		sendxml($xmlOut);

# Make the order number easier to correlate with Google's
	if ($reporttitle == '1') {
		$::Values->{mv_order_subject} = 'Order '.$new_order_no.' : GCOID '.$gco_order_number.' : '.$txtype;
	}  

# run custom final route which cascades 'copy_user' and 'main_entry',  but no receipt page.
		$::Values->{email_copy} = '1';
     	Vend::Order::route_order("gco_final", $cart) if $cart;

    }

#--- chargeback amount -------------------------------------------------------------------------------------
elsif ($$xmlIpn =~ /chargeback-amount-notification/) {
	my $gco_serial_number            = $xmlin->{'serial-number'};
	my $gco_order_number             = $xmlin->{'google-order-number'}; 
	my $gco_timestamp                = $xmlin->{'timestamp'}; 
	my $gco_latest_chargeback_amount = $xmlin->{'latest-chargeback-amount'}->{'content'};
	my $gco_total_chargeback_amount  = $xmlin->{'total-chargeback-amount'}->{'content'};

	   $sth = $dbh->prepare("UPDATE transactions SET txtype='CHARGEBACK', gco_latest_chargeback_amount='$gco_latest_chargeback_amount',gco_total_chargeback_amount='$gco_total_chargeback_amount',gco_timestamp='$gco_timestamp' WHERE gco_order_number='$gco_order_number'");
   	   $sth->execute() or die errmsg("Cannot update transactions tbl for gco '$gco_order_number'");

	my $mailchargeback = <<EOM;
Order $gco_order_number has had a chargeback of $gco_latest_chargeback_amount on $date, making the total
chargeback for this order $gco_total_chargeback_amount.
EOM
  	$::Tag->email({ to => "$merchantemail", from => "$senderemail", reply => "$sendermail",
                subject => "Google order $gco_order_number has had a CHARGEBACK",
                body => "$mailchargeback\n",
             });

    }


#--- refund amount -------------------------------------------------------------------------------------
elsif ($$xmlIpn =~ /refund-amount-notification/) {
	my $gco_serial_number        = $xmlin->{'serial-number'};
	my $gco_order_number         = $xmlin->{'google-order-number'}; 
	my $gco_timestamp            = $xmlin->{'timestamp'}; 
	my $gco_latest_refund_amount = $xmlin->{'latest-refund-amount'}->{'content'};
	my $gco_total_refund_amount  = $xmlin->{'total-refund-amount'}->{'content'};

	   $sth = $dbh->prepare("UPDATE transactions SET txtype='REFUND', gco_latest_refund_amount='$gco_latest_refund_amount',gco_total_refund_amount='$gco_total_refund_amount',gco_timestamp='$gco_timestamp' WHERE gco_order_number='$gco_order_number'");
       $sth->execute() or die errmsg("Cannot update transactions tbl for gco '$gco_order_number'");

	my $mailrefund = <<EOM;
Order $gco_order_number has been refunded for $gco_latest_refund_amount on $date, making the total
refund for this order $gco_total_refund_amount.
EOM
  	$::Tag->email({ to => "$merchantemail", from => "$senderemail", reply => "$sendermail",
                subject => "Google order $gco_order_number has been refunded",
                body => "$mailrefund\n",
             });
       }
    } 
 }

#===================================================================================================
# Now deal with any commands: charge card, ship, refund etc, which might come through an admin panel
#---------------------------------------------------------------------------------------------------

elsif ($gcorequest eq 'command') {

	my $gco_order_number = $::Values->{gco_order_number};
	my $mv_order_number  = $::Values->{mv_order_number};
	my $amount           = $::Values->{gco_amount};
	my $reason           = $::Values->{gco_reason};
	my $carrier          = $::Values->{gco_shipping_company};
           $carrier = 'Other' unless ($carrier =~ /DHL|FedEx|UPS|USPS/i);
	my $tracking_number  = $::Values->{tracking_number};
	my $send_email       = $::Values->{email_text};

#--- charge order -----------------------------------------------------------------------------
if ($gcocmd =~ /charge/) {
    $xmlOut = <<EOX;
<?xml version="1.0" encoding="UTF-8"?>
<charge-order xmlns="http://checkout.google.com/schema/2" google-order-number="$gco_order_number">
    <amount currency="$currency">$amount</amount>
</charge-order>
EOX
   
	my $return = sendxml($xmlOut);
	my $xml    = new XML::Simple();
	my $xmlin  = $xml->XMLin("$return");
	   $::Session->{payment_result}{Terminal} = 'success' unless ($xmlin->{'error-message'});	
       $::Session->{errors}{GoogleCheckout} = $xmlin->{'error-message'}	if ($xmlin->{'error-message'});
    }

#--- add Interchange order number --------------------------------------------------------------
elsif ($gcocmd =~ /add_order_number/) {
       $xmlOut = <<EOX;
<?xml version="1.0" encoding="UTF-8"?>
<add-merchant-order-number xmlns="http://checkout.google.com/schema/2" google-order-number="$gco_order_number">
    <merchant-order-number>$mv_order_number</merchant-order-number>
</add-merchant-order-number>
EOX

	my $return = sendxml($xmlOut);
	my $xml    = new XML::Simple();
	my $xmlin  = $xml->XMLin("$return");
	   $::Session->{payment_result}{Terminal} = 'success' unless ($xmlin->{'error-message'});	
   	   $::Session->{errors}{GoogleCheckout} = $xmlin->{'error-message'} if ($xmlin->{'error-message'});
    }

#--- refund order ------------------------------------------------------------------------------
elsif ($gcocmd =~ /refund/) {
       $xmlOut = <<EOX;
<?xml version="1.0" encoding="UTF-8"?>
<refund-order xmlns="http://checkout.google.com/schema/2" google-order-number="$gco_order_number">
    <amount currency="$currency">$amount</amount>
    <reason>$::Values->{reason}</reason>
</refund-order>
EOX
   
   my $return = sendxml($xmlOut);
   my $xml   = new XML::Simple();
   my $xmlin = $xml->XMLin("$return");
	  $::Session->{payment_result}{Terminal} = 'success' unless ($xmlin->{'error-message'});	
   	  $::Session->{errors}{GoogleCheckout} = $xmlin->{'error-message'} if ($xmlin->{'error-message'});
    }

#--- cancel order -------------------------------------------------------------------------------
elsif ($gcocmd =~ /cancel/) {
       $xmlOut = <<EOX;
<?xml version="1.0" encoding="UTF-8"?>
<cancel-order xmlns="http://checkout.google.com/schema/2" google-order-number="$gco_order_number">
    <reason>$reason</reason>
</cancel-order>
EOX
      
   my $return = sendxml($xmlOut);
   my $xml    = new XML::Simple();
   my $xmlin  = $xml->XMLin("$return");
	  $::Session->{payment_result}{Terminal} = 'success' unless ($xmlin->{'error-message'});	
   	  $::Session->{errors}{GoogleCheckout} = $xmlin->{'error-message'} if ($xmlin->{'error-message'});
    }

#--- authorise order ----------------------------------------------------------------------------
elsif ($gcocmd =~ /authorise/) {
       $xmlOut = <<EOX;
<?xml version="1.0" encoding="UTF-8"?>
<authorize-order xmlns="http://checkout.google.com/schema/2" google-order-number="$gco_order_number"/>      
EOX
   
   my $return = sendxml($xmlOut);
   my $xml    = new XML::Simple();
   my $xmlin  = $xml->XMLin("$return");
	  $::Session->{payment_result}{Terminal} = 'success' unless ($xmlin->{'error-message'});	
   	  $::Session->{errors}{GoogleCheckout} = $xmlin->{'error-message'} if ($xmlin->{'error-message'});
   
   }

#--- archive order ------------------------------------------------------------------------------
elsif ($gcocmd =~ /archive/) {
       $xmlOut = <<EOX;
<?xml version="1.0" encoding="UTF-8"?>
<archive-order xmlns="http://checkout.google.com/schema/2" google-order-number="$gco_order_number" />
EOX
   
   my $return = sendxml($xmlOut);
   my $xml    = new XML::Simple();
   my $xmlin  = $xml->XMLin("$return");
	  $::Session->{payment_result}{Terminal} = 'success' unless ($xmlin->{'error-message'});	
   	  $::Session->{errors}{GoogleCheckout} = $xmlin->{'error-message'} if ($xmlin->{'error-message'});
      
    }

#--- add tracking data --------------------------------------------------------------------------
elsif ($gcocmd =~ /add_tracking/) {
       $xmlOut = <<EOX;
<?xml version="1.0" encoding="UTF-8"?>
<add-tracking-data xmlns="http://checkout.google.com/schema/2" google-order-number="$gco_order_number">
    <tracking-data>
        <carrier>$carrier</carrier>
        <tracking-number>$tracking_number</tracking-number>
    </tracking-data>
</add-tracking-data>
EOX
     
   my $return = sendxml($xmlOut);
   my $xml    = new XML::Simple();
   my $xmlin  = $xml->XMLin("$return");
	  $::Session->{payment_result}{Terminal} = 'success' unless ($xmlin->{'error-message'});	
	  $::Session->{errors}{GoogleCheckout} = $xmlin->{'error-message'} if ($xmlin->{'error-message'});
         
    }

#--- deliver order --------------------------------------------------------------------
elsif ($gcocmd =~ /deliver/) {
       $xmlOut = <<EOX;
<?xml version="1.0" encoding="UTF-8"?>
<deliver-order xmlns="http://checkout.google.com/schema/2" google-order-number="$gco_order_number">
    <tracking-data>
        <carrier>$carrier</carrier>
        <tracking-number>$tracking_number</tracking-number>
    </tracking-data>
    <send-email>$send_email</send-email>
</deliver-order>
EOX
   
   my $return = sendxml($xmlOut);
   my $xml    = new XML::Simple();
   my $xmlin  = $xml->XMLin("$return");
	  $::Session->{payment_result}{Terminal} = 'success' unless ($xmlin->{'error-message'});	
	  $::Session->{errors}{GoogleCheckout} = $xmlin->{'error-message'} if ($xmlin->{'error-message'});
       
       }

#--- end of admin panel commands ----------------------------------------------------------------------------
    
    }
 
}

#------------------
sub new {
  my (%args) = @_;
  my $class = 'Vend::Payment::GoogleCheckout';
  my $self;
     $self->{__merchant_id}        = $args{merchant_id};
     $self->{__merchant_key}       = $args{merchant_key};
     $self->{__base_gco_server}    = $args{gco_server};
     $self->{__currency_supported} = $args{currency_supported} || 'USD';
     $self->{__xml_schema}         = $args{xml_schema} || 'http://checkout.google.com/schema/2';
     $self->{__xml_version}        = $args{xml_version} || '1.0';
     $self->{__xml_encoding}       = $args{xml_encoding} || 'UTF-8';
# ::logDebug(":GCO:".__LINE__.": class=$class; id=$self->{__merchant_id}; key=$self->{__merchant_key} server=$self->{__base_gco_server}");
  return bless $self => $class;
}

sub sendxml {
use MIME::Base64;
  my $xmlOut = shift;
  my $agent  = LWP::UserAgent->new;
  my $data   = "$merchantid:$merchantkey";
  my $signature = encode_base64($data, "");
     $header  = HTTP::Headers->new;
     $header->header('Authorization' => "Basic " . $signature);
     $header->header('Content-Type'  => "application/xml; charset=UTF-8");
     $header->header('Accept'        => "application/xml");
  my $request = HTTP::Request->new(POST => $gcourl, $header, $xmlOut);
  my $response = $agent->request($request);
::logDebug(":GCO:".__LINE__.": sendxml: gcourl=$gcourl\nxmlOut=$xmlOut");
  return $response->content;
}

1;
