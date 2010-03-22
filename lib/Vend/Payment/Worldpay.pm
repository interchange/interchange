# Vend::Payment::Worldpay - Interchange Worldpay support
#
# worldpay.pm, v 1.0.0, June 2009
#
# Copyright (C) 2009 Nimbus Designs Ltd T/A TVCables and 
# Zolotek Ltd All rights reserved.
#
# Authors: Andy Smith <andy@tvcables.co.uk>, http://www.tvcables.co.uk
# Lyn St George <info@zolotek.net, http://www.zolotek.net>
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



package Vend::Payment::Worldpay;

=head1 Interchange Worldpay Support

Vend::Payment::Worldpay $Revision: 1.0.0 $

http://kiwi.zolotek.net is the home page with the latest version.

=head1 This package is for the 'Worldpay' payment system.


=head1 Quick Start Summary

1 Place this module in <IC_root>/lib/Vend/Payment/worldpay.pm

2 Call it in interchange.cfg with:
    Require module Vend::Payment::Worldpay.
    
3 Add a new route into catalog.cfg (options for the last entry in parentheses):
  Route worldpay host https://select.wp3.rbsworldpay.com/wcc/purchase (Live Payment URL)
  Route worldpay testhost https://secure-test.wp3.rbsworldpay.com/wcc/dispatcher (Test payment URL)
  Route worldpay instid 12345 (Your Worldpay instID)
  Route worldpay currency GBP (defaults to GBP)
  Route worldpay testmode 100 (Set to 100 for test mode 0 for live - default live)
  Route worldpay callbackurl (The URL Worldpay will callback eg www.yourstore.co.uk/cgi-bin/yourname/wpcallback.html)
  Route worldpay callpw (Callback password, set any password you like and set it the same in the WP Admin Panel)
  Route worldpay fixcontact 1 (If set to 1 customers cannot ammend address details when they get to worldpay, 0 to allow changes)
  Route worldpay desc 'Yourstore Order' (Text to send in the desc field eg 'Yourstore Order')
  Route worldpay reporttitle 1 (If set to 1 will modifty order report title to include transaction ID)
  Route worldpay update_status processing (Text to set order status on success eg processing, default pending)
  Route worldpay wpcounter (Defines the counter for temporary order number, defaults to etc/username)

4 Create a new locale setting for en_GB as noted in "item currency" below, and copy the
public space interchange/en_US/ directory to a new interchange/en_GB/ one. Ensure that any
other locales you might use have a correctly named directory as well. Ensure that this locale
is found in your version of locale.txt (and set up GB as opposed to US language strings to taste).

5 Add a new order profile in etc/profiles.order

__NAME__                            worldpay
fname=required
b_fname=required
lname=required
b_lname=required
address1=required
b_address1=required
city=required
b_city=required
state=required
b_state=required
zip=required
b_zip=required
&fatal = yes
email=required
email=email
&set=mv_payment worldpay
&set=psp worldpay
&set=mv_payment_route worldpay
&set=mv_order_route worldpay
&final = yes
&setcheck = payment_method worldpay
__END__

6 Add the following fields to the transactions table if they do not already exist (run from a mysql prompt)

ALTER TABLE `transactions` ADD `wp_transtime` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci ,
ADD `wp_cardtype` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `wp_countrymatch` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `wp_avs` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `wp_risk` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `wp_authentication` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `wp_authamount` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `wp_order_number` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `lead_source` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `referring_url` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `txtype` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `cart` BLOB;

And run these to allow for temporary order numbers of greater than the default 14 character field type
ALTER TABLE `transactions` MODIFY `order_number` varchar(32);
ALTER TABLE `orderline` MODIFY `order_number` varchar(32);

7. Add the following to etc/log_transaction just BEFORE [/import][/try]

lead_source: [data session source]
referring_url: [data session referer]
cart: [calc]uneval($Items)[/calc]

8. Still in etc/log_transaction, find the section that starts "Set order number in values: " and insert
this just before it:

[if value mv_order_profile =~ /worldpay/]
[value name=mv_order_number set="[scratch purchaseID]" scratch=1]
[else]
and a closing [/else][/if] at the end of that section, just before the 
"Set order number in session:"
line. The order number is generated by the module and passed to Worldpay at an early stage, and then
passed back to Interchange with a callback. This prevents Interchange generating another order number.
The module will not currently work with IC versions lower than 5.2 that use a tid counter defined in
catalog.cfg. The initial order number uses the username.counter number prefixed with 'WPtmp', and a normal
order number is created and the initial order number replaced only when Worldpay callsback that the card
has been charged. This is to avoid gaps in the order number sequence caused by customers abandoning the 
transaction.

9. In etc/log_transction, change the line:- 
[elsif variable MV_PAYMENT_MODE]
to
[elsif value mv_order_profile =~ /worldpay/] add an OR if required
eg [elsif value mv_order_profile =~ /googlecheckout|worldpay/]

Then in the [calc] block immediately below insert this line: 

	undef $Session->{payment_result}{MStatus};
	
Within the same section change the following two instances of
[var MV_PAYMENT_MODE] to [value mv_payment_route]

10. Creat a callback page in /pages called wpcallback.html or any name you prefer, set this page in
the Worldpay admin panel, the module also supports dynamic callback pages where different catalogs can
have different callback pages, if using this the callpage URL must be set in the route in catalog.cfg as
described above.

At the top of the callback page include the following line:-
[charge route="worldpay" worldpayrequest="callback"]

At the end of the charge process Worldpay do not allow redirection to a receipt page, if you do this they
claim they will disable the callback feature or even suspend your account, how nice! You can however re-direct if
the transaction is cancelled

Worldpay will suck the wpcallback page back to their server and display it for you, this can be used to display a receipt page.
The page will interpolate before being sucked to Worldpay so most items such as fname lname adress fields etc are usuable on the page.
To display banners and logos they need to be pre-loaded onto the Worldpay server

At the top of the callback page just below the [charge route="worldpay" worldpayrequest="callback"] you can test for a sucessful transaction as follows:-

[if type="cgi" term="transStatus" op="eq" compare="Y"] 
[and type="cgi" term="callbackPW" op="eq" compare="yourcallbackpassword"] 

Display a receipt page

[else]

Display a cancelled page or bounce the customer back to site etc

[/else]
[/if]

11. Checkout button

On your checkout page include a button that sets the route and submits the checkout form eg

[button
    mv_click=worldpay
    text="Place Order"
    hidetext=1
    form=checkout
   ]
   mv_order_profile=worldpay
   mv_order_route=worldpay
   mv_todo=submit
[/button]


=head1 PREREQUISITES

  Net::SSLeay
    or
  LWP::UserAgent and Crypt::SSLeay

  wget - a recent version built with SSL and supporting the 'connect' timeout function.


=head1 DESCRIPTION

The Vend::Payment::Worldpay module implements the Worldpay() routine for use with
Interchange. It is _not_ compatible on a call level with the other Interchange
payment modules.

To enable this module, place this directive in <interchange.cfg>:

    Require module Vend::Payment::Worldpay

This I<must> be in interchange.cfg or a file included from it.

The module collects the data from a checkout form and formats it with a re-direct to
the Worldpay payment server. The customers details and cart is logged in the database
before going to Worldpay with a temporary order number of the form WPtmpUxxxx where Uxxxx
is derived from the username counter

If the transaction is sucessful the module processes the callback response from Worlday, if
sucessfull the temporary order number is converted to an Interchange order number and a final
route is run to send out the report and customer emails. Cancelled transactions remain in the
database with the temporary order numbers but are automatically archived.

The module will also optionally decrement the inventory on a sucessfull transaction, if used
the inventory decrement in log transaction should be disabled by setting the appropriate variable

=head1 The active settings.

The module uses several of the standard settings from the Interchange payment routes.
Any such setting, as a general rule, is obtained first from the tag/call options on
a page, then from an Interchange order Route named for the mode in catalog.cfg,
then a default global payment variable in products/variable.txt, and finally in
some cases a default will be hard-coded into the module.

=over

=item instid

Your installation id supplied by Worldpay, the module cannot be used without an instid, set in
catalog.cfg

=item currency

Worldpay requires that a currency code be sent, using the 3 letter ISO currency code standard,
eg, GBP, EUR, USD. The value is taken firstly from the route parameter in catalog.cfg and
defaults to GBP

=item testmode

Sets whether the system runs test or live transactions, set to 0 (default) for live transactions, 
or 100 for test transactions.

=item callbackurl

If using dynamic callback pages with Worldpay, set you callback page without the http eg:-

www.yourstore.co.uk/cgi-bin/yourstore/wpcallback.html

=item callpw

Sets the password to compare with the callback, set this the same as the password in the Worldpay
admin panel


=item desc

Sets the text for the desc field sent to Worldpay and will appear on the transaction reciper, eg
'Yourstore Order'

=item fixcontact

Fixes the information send to Worldpay so it cannot be modified by the customer at Worldpay, set to 1
to fix or 0 to allow the customer to edit address at Worldpay.

=item reporttitle

Set to 1 to change the email report title to include the Worldpay transaction ID, set to zero for
standard report email title

=item update_status

Allows the order status to be set to any desired value after a sucessfull transaction, eg set to processing
and all successfull transactions will have status processing, defaults to pending

=item dec_inventory

Set to 1 for module to decrement the inventory on a sucessfull transaction, if used disable decrement via
log_transaction.

=back

=head2 Testing

Set testmode 100 in catalog.cfg

Add some items to the cart and place the order, the module will re-direct you
to Worldpay where you can select the card type to pay with. Enter some test card details and check
the order is logged in the database ok and emails sent out.

Test card numbers

Mastercard
5100080000000000

Visa Delta - UK
4406080400000000

Visa Delta - Non UK
4462030000000000

Visa
4911830000000

Visa
4917610000000000

American Express
370000200000000

Diners
36700102000000

JCB
3528000700000000

Visa Electron (UK only)
4917300800000000

Solo
6334580500000000

Solo
633473060000000000

Discover Card
6011000400000000

Laser
630495060000000000

Maestro
6759649826438453

Visa Purchasing
4484070000000000


=head1 AUTHORS

Andy Smith <andy@tvcables.co.uk> with help from and based on code by
Lyn St George <info@zolotek.net>, which in turn was based on original
code by Mike Heins <mike@perusion.com> and others.

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

::logGlobal("%s 1.0.0 payment module initialised, using %s", __PACKAGE__, $selected)
        unless $Vend::Quiet;

}

package Vend::Payment;
use strict;

#use Data::Dumper;

sub worldpay {
	my ($amount, $actual, $opt, $worldpayrequest, $cart, $orderID, $purchaseID, %result);
	
	# Amount to send with 2 decimals and no symbol
	   $amount =  $::Values->{amount} || charge_param('amount') || Vend::Interpolate::total_cost();
	   $amount =~ s/^\D*//g;
	   $amount =~ s/\,//g;
	   $amount =  sprintf '%.2f', $amount;
	   
	   
	# Transaction variables to send to worldpay.
	my $host = charge_param('host') || 'https://select.wp3.rbsworldpay.com/wcc/purchase'; #Live 
	my $testhost = charge_param('testhost') || 'https://secure-test.wp3.rbsworldpay.com/wcc/dispatcher';#Test 
	my $instId = charge_param('instid') || '00000';
	my $currency = charge_param('currency') || 'GBP';
	my $testMode = charge_param('testmode') || '0';
	my $callbackurl	= charge_param('callbackurl') || '';	#URL on your server WP will callback
	my $callpw = charge_param('callpw') || 'password'; #Must be same as Worldpay admin panel callback password
	my $desc = charge_param('desc') || '';	#Transaction description
	my $fixcontact = charge_param('fixcontact') || '0';    #0=details editable at WP 1=details fixed as sent 
	my $affsubtotal = $Tag->subtotal({noformat => 1,});# This is used to send subtotal as as MC_ parameter to read back for affilate sales calculations
	   $affsubtotal =~ s/^\D*//g;
	   $affsubtotal =~ s/\,//g;
	   $affsubtotal =  sprintf '%.2f', $affsubtotal;
	
::logDebug("WP:".__LINE__.": Session = $::Session->{id} Host = $host instid = $instId currency = $currency testmode = $testMode callbackurl = $callbackurl pw = $callpw desc = $desc fix = $fixcontact  affsubtotal=$affsubtotal");

	if ($testMode > '0') {	# send to test url not live
		$host = $testhost;
	}

	my $ordernumber  = charge_param('ordernumber') || 'etc/order.number';
	my $wpcounter   = charge_param('wpcounter') || 'etc/username.counter'; 

	$worldpayrequest  = charge_param('worldpayrequest')  || $::Values->{worldpayrequest} || 'post';
	$opt     = {};
	
::logDebug("WP:".__LINE__.": Request = $worldpayrequest");

##-----------Post Information and send customer to Worldpay------------##
if ($worldpayrequest eq 'post') {	
::logDebug("WP:".__LINE__.": Sending customer to Worldpay");
::logDebug("WP:".__LINE__.": TestMode = $testMode : Host = $host");

  my $separator = '&#10;';
  my $name = "$::Values->{b_fname} $::Values->{b_lname}";
  my $address = "$::Values->{b_address1}%0A$::Values->{b_address2}%0A$::Values->{b_city}%0A$::Values->{b_state}"; #%0A is the line feed separator between address lines
  my $postcode = "$::Values->{b_zip}";
  my $country = "$::Values->{b_country}";
  my $email = "$::Values->{email}";
  my $tel = "$::Values->{phone_night}"; #some may wish to use phone_day

	 $orderID = gen_order_id($opt);
	 $::Scratch->{orderID} = $orderID;

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
    $purchaseID = 'WPtmp'.Vend::Interpolate::tag_counter("$wpcounter");
#::logDebug(":WP:".__LINE__.": purchaseID=$purchaseID;");
}
    
    $::Scratch->{purchaseID} = $purchaseID;

  my $cartId = $::Scratch->{purchaseID};



#go to worldpay
  my $redirecturl = "$host?instId=$instId&currency=$currency&testMode=$testMode&amount=$amount&cartId=$cartId&desc=$desc&name=$name&address=$address";
	 $redirecturl .= "&postcode=$postcode&country=$country&email=$email&tel=$tel&MC_mv_order_number=$cartId&MC_callback=$callbackurl&MC_affsubtotal=$affsubtotal";
	
	 $redirecturl .= "&fixContact" if ($fixcontact == 1);
	 $redirecturl = Vend::Util::header_data_scrub($redirecturl);

::logDebug("WP:".__LINE__.": URL = $redirecturl");
 
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

####----------------Handle the callback from Worldpay--------------####
elsif ($worldpayrequest eq 'callback'){

	my $newsess = $::Session->{id};	
::logDebug("WP:".__LINE__.": Processing Callback Session = $newsess");

	my $reporttitle = charge_param('reporttitle') || '0';
	my $update_status = charge_param('update_status') || 'pending';
	my $dec_inventory = charge_param('dec_inventory') || '0';

#Capture all callback fields from CGI
	my $transid		= $::CGI->{transId}; 		#transaction ID
	my $check_testmode	= $::CGI->{testMode};		#returns testmode value 0 live anything higher test mode
	my $transstatus		= $::CGI->{transStatus}; 	#Y=Sucess C=Cancelled
	my $authamount		= $::CGI->{authAmount};		#Authorised amount
	my $transtime		= $::CGI->{transTime};		#Time of transaction
	my $authcurrency	= $::CGI->{authCurrency};	#Currency of authorisation
	my $rawauthmessage	= $::CGI->{rawAuthMessade};	#Raw auth message
	my $callbackpw		= $::CGI->{callbackPW};		#Callback password as set in admin panel
	my $cardtype		= $::CGI->{cardType};		#Card type used
	my $countrymatch	= $::CGI->{countryMatch};	#Y=Match N=No match B=Not available I=Country not supplied S=Country issue not available
	my $avs			= $::CGI->{AVS};		#AVS Results
	my $wafmerchmessage	= $::CGI->{wafMerchMessage};	#Risk result
	my $authentication	= $::CGI->{authentication};	#VbyV or Mastercard Securecode authentication type
	my $ipaddress		= $::CGI->{ipAdress};		#Shopper IP address

::logDebug("WP:".__LINE__.": transid=$transid testmode=$check_testmode transstatus=$transstatus authamount=$authamount transtime=$transtime authcurrency=$authcurrency rawauthmessage=$rawauthmessage");
::logDebug("WP:".__LINE__.": callbackpw=$callbackpw cardtype=$cardtype countrymatch=$countrymatch avs=$avs wafmerchmessage=$wafmerchmessage authentication=$authentication ipaddress=$ipaddress");

	my $wp_order_number	= $::CGI->{MC_mv_order_number};

	my $db  = dbref('transactions') or die errmsg("cannot open transactions table");
	my $dbh = $db->dbh() or die errmsg("cannot get handle for tbl 'transactions'");
	my $sth;
	my $stho;

::logDebug("WP:".__LINE__.": Callback order number = $wp_order_number");



#if success
if (($transstatus eq 'Y') and ($callbackpw eq $callpw)) { 
::logDebug("WP:".__LINE__.": Transaction Suucessful");

	   $sth = $dbh->prepare("SELECT total_cost,email,txtype,order_number FROM transactions WHERE order_number='$wp_order_number'") or die errmsg("Cannot select from transactions tbl for $wp_order_number");
	   $sth->execute() or die errmsg("Cannot get data from transactions tbl");
    my @d = $sth->fetchrow_array;
    my $order_total = $d[0];
    my $email       = $d[1];
    my $txtype      = $d[2];
    my $old_tid     = $d[3];
    my $new_order_no  = $::Values->{mv_order_number} = Vend::Interpolate::tag_counter("$ordernumber") ; #generate the IC Order Number
    my $charged = 'WP Charged';

#Check if transaction was in test mode
    if ($check_testmode > '0') { # Transaction was in test mode
		$update_status = $update_status .'-TEST'; #Append Test to end of order status to show order was made in test mode
		$charged = $charged .'-TEST'; #Variable we write to txtype
		}    
::logDebug("WP:".__LINE__.": Check testmode = $check_testmode Update Status = $update_status Set txtype = $charged");
		
#Replace temporary order number with IC order number
::logDebug("WP:".__LINE__.": Replacing order number: Old TID = $old_tid with New Order No = $new_order_no");
	  $sth = $dbh->prepare("UPDATE transactions SET code='$new_order_no', order_number='$new_order_no', txtype='$charged' WHERE order_number='$wp_order_number'");
	  $stho = $dbh->prepare("UPDATE orderline SET code=replace(code, '$old_tid', '$new_order_no'), order_number='$new_order_no' WHERE order_number='$old_tid'");
	  $stho->execute() or die errmsg("Cannot update transactions tbl for WP '$wp_order_number'");
	  $sth->execute() or die errmsg("Cannot update transactions tbl for WP '$wp_order_number'");
	   
#Log transaction information & change order status
::logDebug("WP:".__LINE__.": Logging transaction details to tbl for order $new_order_no");
	  $sth = $dbh->prepare("UPDATE transactions SET status='$update_status', order_id='$transid', wp_transtime='$transtime', wp_cardtype='$cardtype', wp_countrymatch='$countrymatch', wp_avs='$avs', wp_risk='$wafmerchmessage', wp_authentication='$authentication', wp_authamount='$authamount' WHERE order_number='$new_order_no'");
	  $stho = $dbh->prepare("UPDATE orderline SET status='$update_status' WHERE order_number='$new_order_no'");
	  $stho->execute() or die errmsg("Cannot update orderline tbl for worldpay order '$new_order_no'");
	  $sth->execute() or die errmsg("Cannot update transactions tbl for worldpay order '$new_order_no'");
	
#Read the order details and cart from the database
       $sth = $dbh->prepare("SELECT total_cost,email,order_number,fname,lname,company,address1,address2,city,state,zip,country,phone_day,fax,b_fname,b_lname,b_company,b_address1,b_address2,b_city,b_state,b_zip,b_country,shipmode,handling,order_date,lead_source,referring_url,txtype,locale,currency_locale,cart,session,salestax,shipping,b_phone FROM transactions WHERE order_number='$new_order_no'") or die errmsg("Cannot select from transactions tbl for $wp_order_number");
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
    my $order_date = $::Values->{order_date} = $d[25];
    my $lead_source = $::Session->{lead_source} = $d[26];
    my $referring_url = $::Session->{referer} = $d[27];
    my $txtype = $::Values->{txtype} = $d[28];
    my $mv_locale = $d[29];
    my $mv_currency = $d[30];
    my $cart = $d[31];
    my $session = $d[32];
    my $salestax = $d[33];
    my $shipping = $d[34];
    my $phone_night = $::Values->{phone_night} = $d[35];
    
    #todo add evening phone
    
	   $Tag->assign(  { shipping => $shipping, }  );
	   $Tag->assign(  { salestax => $salestax, }  );
	  
	   $::Values->{mv_handling} = 1;
	   $Tag->assign(  { handling => $handling, }  );
    
	my (@cart, $acart);
       $cart =~ s/\"/\'/g;
       $cart =~ s/\\//;
	   @cart = eval($cart); 
	   $acart = eval ($cart);
	   ::logDebug("WP:".__LINE__.": cart=$cart Email=$email");	
	   
	   $::Values->{mv_payment} = 'Worldpay';
	   $::Values->{wp_order_number} = $wp_order_number;
	   $::Session->{values}->{iso_currency_code} = $currency;
	   $::Session->{scratch}->{mv_locale} = $mv_locale;
	   $::Session->{scratch}->{mv_currency} = $mv_currency;
 
::logDebug("WP:".__LINE__.": Shipmode = $shipmode Shipping = $shipping Tax = $salestax Handling = $handling");


#Set new report title with final order number and WP transaction ID
	if ($reporttitle == '1') {
		my $amt = sprintf '%.2f', $order_total;
		$::Values->{mv_order_subject} = 'Order '.$new_order_no.' : WPID:'.$transid.' : '.$mv_currency.''.$amt.' : '.$charged;
	}       


	if ($dec_inventory == '1') {
#Decrement item quantities in inventory table
	my $dbi  = dbref('inventory') or die errmsg("cannot open inventory table");
	my $dbhi = $dbi->dbh() or die errmsg("cannot get handle for tbl 'inventory'");
	my ($sthi, $itm, $qty);
	
	foreach my $items (@{$acart})
	{ 
		$itm = $items->{'code'};
		$qty = $items->{'quantity'};
		$sthi = $dbh->prepare("UPDATE inventory SET quantity = quantity -'$qty' WHERE sku = '$itm'");
		$sthi->execute() or die errmsg("Cannot update table inventory");
::logDebug("WP:".__LINE__.": Decremented inventory for $itm by $qty");
	}
}


# run custom final route which cascades 'copy_user' and 'main_entry', ie no receipt page.
    	Vend::Order::route_order("wp_final", @cart) if @cart; 


::logDebug("WP:".__LINE__.": End worldpay transaction success");
}

elsif ($callbackpw ne $callpw) { 
#This should never happen unless someone tries to simulate transactions without knowing the callback password or the password is entered incorrectly in catalog.cfg or the WP admin panel
#Transaction logged as txtype WP Pass Error and status passerror
::logDebug("WP:".__LINE__.": Callback password was incorrect");
::logDebug("WP:".__LINE__.": Logging transaction with callback password failure to tbl for order $wp_order_number");
	$sth = $dbh->prepare("UPDATE transactions SET status='passerror', txtype='WP Pass Error', order_id='$transid', wp_transtime='$transtime', wp_cardtype='$cardtype', wp_countrymatch='$countrymatch', wp_avs='$avs', wp_risk='$wafmerchmessage', wp_authentication='$authentication', wp_authamount='$authamount' WHERE order_number='$wp_order_number'");
	$stho = $dbh->prepare("UPDATE orderline SET status='passerror' WHERE order_number='$wp_order_number'");
	$stho->execute() or die errmsg("Cannot update orderline tbl for worldpay order '$wp_order_number'");
	$sth->execute() or die errmsg("Cannot update transactions tbl for worldpay order '$wp_order_number'");
}

else {
#transaction has been cancelled
::logDebug("WP:".__LINE__.": Transaction for order $wp_order_number was cancelled");

#log details of cancelled transaction & set archived to 1 so it won't show in admin panel
::logDebug("WP:".__LINE__.": Logging cancelled transaction details to tbl for order $wp_order_number");
	$sth = $dbh->prepare("UPDATE transactions SET status='cancelled', archived='1', txtype='WP Cancelled', order_id='$transid', wp_transtime='$transtime', wp_cardtype='$cardtype', wp_countrymatch='$countrymatch', wp_avs='$avs', wp_risk='$wafmerchmessage', wp_authentication='$authentication', wp_authamount='$authamount' WHERE order_number='$wp_order_number'");
	$stho = $dbh->prepare("UPDATE orderline SET status='cancelled' WHERE order_number='$wp_order_number'");
	$stho->execute() or die errmsg("Cannot update orderline tbl for worldpay order '$wp_order_number'");
	$sth->execute() or die errmsg("Cannot update transactions tbl for worldpay order '$wp_order_number'");

	}

  }
	
}
 

package Vend::Payment::Worldpay;

1;

