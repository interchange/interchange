# Vend::Payment::Worldpay - Interchange Worldpay support
#
# worldpay.pm, v 1.0.2, October 2010
#
# Copyright (C) 2009 Nimbus Designs Ltd T/A TVCables and 
# Zolotek Resources Ltd All rights reserved.
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

Vend::Payment::Worldpay $Revision: 1.0.2 $

http://kiwi.zolotek.net is the home page with the latest version.

=head1 This package is for the 'Worldpay' payment system.


=head1 Quick Start Summary

1 Place this module in <IC_root>/lib/Vend/Payment/Worldpay.pm

2 Call it in interchange.cfg with:
    Require module Vend::Payment::Worldpay.
    
3 Add a new route into catalog.cfg (options for the last entry in parentheses):
  Route worldpay host https://secure.wp3.rbsworldpay.com/wcc/purchase (Live Payment URL)
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
  Route worldpay md5pw yourmd5secret (required in this version, will die without it)

## md5 code ##
  Enter the following into the worldpay control panel:-
  Your MD5 secret as set in catalog.cfg
  In the signature fields box enter amount:instId:MC_affsubtotal:currency

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
ADD `wp_transtime` VARCHAR( 64 ) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `lead_source` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `referring_url` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `txtype` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `email_copy` CHAR(1) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `mail_list` varCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `cartid` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_general_ci,
ADD `cart` BLOB;


And run these to allow for temporary order numbers of greater than the default 14 character field type
ALTER TABLE `transactions` MODIFY `order_number` varchar(32);
ALTER TABLE `orderline` MODIFY `order_number` varchar(32);

Also add 'cartid' to the orderline table.

7. Add the following to etc/log_transaction just BEFORE [/import][/try]

lead_source: [data session source]
referring_url: [data session referer]
cart: [calc]uneval($Items)[/calc]
cartid: [value mv_order_number]
email_copy: [value email_copy]
mail_list: [value mail_list]

8. Still in etc/log_transaction, find the section that starts "Set order number in values: " and insert
this just before it:

NB/ this only applies if your IC is greater than v 5.2, otherwise skip sections 8 & 9

[if value mv_order_profile =~ /worldpay/]
[value name=mv_order_number set="[scratch purchaseID]" scratch=1]
[else]
and a closing [/else][/if] at the end of that section, just before the 
"Set order number in session:"
line. The order number is generated by the module and passed to Worldpay at an early stage, and then
passed back to Interchange with a callback. This prevents Interchange generating another order number.
The module will not currently work with IC versions lower than 5.2 that use a tid counter defined in
catalog.cfg. The initial order number uses the username.counter number prefixed with 'WPtmp', and a normal
order number is created and the initial order number replaced only when Worldpay calls back that the card
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

10. Create a callback page in /pages called wpcallback.html or any name you prefer, set this page in
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

At the top of the callback page just below the [charge route="worldpay" worldpayrequest="callback"] you can test for a successful transaction as follows:-

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
   mv_order_route=log
   mv_todo=submit
[/button]

NB/ for IC versions 5.2 and older, make the button so as to call the 'wprequest.html' page:

[button
    mv_click=worldpay
    text="Place Order"
    hidetext=1
    form=checkout
   ]
   mv_nextpage=ord/wprequest
   mv_order_route=log
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

If the transaction is successful the module processes the callback response from Worlday, if
successful the temporary order number is converted to an Interchange order number and a final
route is run to send out the report and customer emails. Cancelled transactions remain in the
database with the temporary order numbers but are automatically archived.

The module will also optionally decrement the inventory on a successful, if used
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

Allows the order status to be set to any desired value after a successful transaction, eg set to processing
and all successfull transactions will have status processing, defaults to pending

=item dec_inventory

Set to 1 for module to decrement the inventory on a successful transaction, if used disable decrement via
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


=head1 changelog
 - v1.0.2 November 2011, added encryption from Andy to main request as defence against tampering
 - v1.0.1 not released: October 2010, made work with IC v4.8.7 - needs to have 'use strict' commented out, and a redirection page
  

=head1 AUTHORS

Andy Smith <andy@tvcables.co.uk> with help from and based on code by
Lyn St George <lyn@zolotek.net>, which in turn was based on original
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
            use Digest::MD5 qw(md5_hex);
            require Encode;
             import Encode qw(encode decode);
             import HTTP::Request::Common qw(POST);
            $selected = "LWP and Crypt::SSLeay";
        };

        $Vend::Payment::Have_LWP = 1 unless $@;
    }

    unless ($Vend::Payment::Have_Net_SSLeay or $Vend::Payment::Have_LWP) {
        die __PACKAGE__ . " requires Net::SSLeay or Crypt::SSLeay, " . $@;
    }

::logGlobal("%s 1.0.2 payment module initialised, using %s", __PACKAGE__, $selected)
        unless $Vend::Quiet;

}

package Vend::Payment;
use strict; 

sub worldpay {
	my ($amount, $actual, $opt, $worldpayrequest, $cart, $orderID, $purchaseID, %result, $dbh, $sql, $sth, $stho);

#::logDebug("WP".__LINE__.": amnt=$amount, req=$worldpayrequest, pID=$purchaseID");	
	# Amount to send with 2 decimals and no symbol
	   $amount =  $::Values->{amount} || charge_param('amount') || Vend::Interpolate::total_cost();
	   $amount =~ s/^\D*//g;
	   $amount =~ s/\,//g;
	   $amount =  sprintf '%.2f', $amount;
	   
	my $oldic  = charge_param('oldic');   
 
	# Transaction variables to send to worldpay.
	my $host = charge_param('host') || 'https://secure.wp3.rbsworldpay.com/wcc/purchase'; #Live 
	my $testhost = charge_param('testhost') || 'https://secure-test.wp3.rbsworldpay.com/wcc/purchase';#Test 
	my $instId = charge_param('instid');
	my $accId1 = charge_param('accid1');
	my $currency = charge_param('currency') || 'GBP';
    my $charged = charge_param('authtype') ||  'WP PreAuthed';
	my $testMode = charge_param('testmode') || '0';
	my $authMode = $::Values->{'authmode'} || charge_param('authmode') || 'E';
	my $callbackurl	= charge_param('callbackurl');	#URL on your server WP will callback, including .html extension
	my $callpw = charge_param('callpw'); #Must be same as Worldpay admin panel callback password
	my $desc;	#Transaction description, set to CartID for easier reference
	my $tmpPrefix = charge_param('tmporderprefix') || 'Cart';
	my $fixcontact = charge_param('fixcontact') || '0';    #0=details editable at WP 1=details fixed as sent 
	my $affsubtotal = Vend::Interpolate::subtotal(); # This is used to send subtotal as as MC_ parameter to read back for affilate sales calculations
	   $affsubtotal =~ s/^\D*//g;
	   $affsubtotal =~ s/\,//g;
	   $affsubtotal =  sprintf '%.2f', $affsubtotal;
	
#::logDebug("WP:".__LINE__.": Session = $Vend::Session->{id} Host = $host instid = $instId currency = $currency testmode = $testMode callbackurl = $callbackurl pw = $callpw desc = $desc fix = $fixcontact  affsubtotal=$affsubtotal");

	   $host = $testhost if ($testMode > '0');# send to test url not live

	my $ordernumber  = charge_param('ordernumber') || 'etc/order.number';
	my $wpcounter   = charge_param('wpcounter') || 'etc/username.counter'; 
	my $username    = $Vend::Session->{'username'};
	my $allowbilling = charge_param('allow_billing') || '';
	my $md5pw = charge_param('md5pw') or die "No MD5 password set in route";

	   $worldpayrequest  = charge_param('worldpayrequest')  || $::Values->{worldpayrequest} || 'post';
	   $opt     = {};

  
#::logDebug("WP:".__LINE__.": Request = $worldpayrequest; un=$username, $::Values->{mv_username},");
	   $::Values->{'mv_order_number'} = '';
	
##-----------Post Information and send customer to Worldpay------------##
if ($worldpayrequest eq 'post') {	
#::logDebug("WP:".__LINE__.": Sending customer to Worldpay");
#::logDebug("WP:".__LINE__.": TestMode = $testMode : Host = $host");

	my $separator = '&#10;';
	my $name = "$::Values->{fname} $::Values->{lname}" || "$::Values->{b_fname} $::Values->{b_lname}";
	my $address = "$::Values->{address1}%0A$::Values->{address2}%0A$::Values->{city}%0A$::Values->{state}" || "$::Values->{b_address1}%0A$::Values->{b_address2}%0A$::Values->{b_city}%0A$::Values->{b_state}"; #%0A is the line feed separator between address lines
	my $postcode = "$::Values->{zip}" || $::Values->{b_zip};
	my $country = "$::Values->{country}" || "$::Values->{b_country}";
	my $email = "$::Values->{email}";
	my $tel = "$::Values->{phone_night}" || "$::Values->{phone_day}"; #some may wish to use phone_day

	   $orderID = gen_order_id($opt);
	   $::Scratch->{orderID} = $orderID;

# Disable order number creation in log_transaction and create it here instead, unless IC is old
	if ($::Values->{inv_no}) {
	  $purchaseID = $::Values->{inv_no};
		  }
	else{
# Use temporary number as the initial order number, and only replace upon successful order completion
		$purchaseID = "$tmpPrefix".Vend::Interpolate::tag_counter("$wpcounter");
		$Vend::Session->{mv_order_number} = $::Values->{mv_order_number} = $purchaseID if ($oldic == 1);# prevents early ICs setting order number prior to log_transaction
	::logDebug("WP:".__LINE__.": purchaseID=$purchaseID; $Vend::Session->{mv_order_number}");
	}
    
    my $cartId = $desc = $::Scratch->{purchaseID} = $purchaseID;

	my $md5data = $md5pw . ":" . $amount . ":" . $instId . ":" . $affsubtotal . ":" . $currency;
	my $signature = md5_hex($md5data);  
#::logDebug("WP:".__LINE__.": md5pw = $md5pw md5data = $md5data signature =$signature");

#go to worldpay
  my $redirecturl = "$host?signature=$signature&instId=$instId&currency=$currency&testMode=$testMode&authMode=$authMode&amount=$amount&cartId=$cartId&desc=$desc&name=$name&address=$address";
	 $redirecturl .= "&postcode=$postcode&country=$country&email=$email&tel=$tel&MC_mv_order_number=$cartId&MC_callback=$callbackurl";
	 $redirecturl .= "&fixContact" if ($fixcontact == 1);
	 $redirecturl .= "&accId1=$accId1" if $accId1;
	 $redirecturl =~ s/(?:%0[da]|[\r\n]+)+//ig; ## "HTTP Response Splitting" Exploit Fix

	 $::Scratch->{'redirecturl'} = $redirecturl; # for old versions of IC needing a redirection page
#::logDebug("WP:".__LINE__.": redirectURL = $redirecturl");

# Fake the result so that IC can log the transaction
	$result{Status}     = 'success';
	$result{MStatus}    = 'success';
	$result{'order-id'} = $orderID;
#::logDebug("WP".__LINE__.": resSt=$result{'Status'}; resMSt=$result{'MStatus'},resoid=$result{'order-id'}");

# Delete any stale baskets, ie with tmpID but without proper order numbers; only works if user is forced
# to login prior to ordering and uses same username
    $dbh = dbconnectwp() or warn "###dbh failed\n";
	$sql = "DELETE FROM transactions WHERE order_number LIKE '$tmpPrefix%' AND username='$username'";
	$sth = $dbh->prepare("$sql") or warn "###sth failed\n";
	$sth->execute() or die errmsg("###Transactions tbl failed") if $username;
	$sql = "DELETE FROM orderline WHERE order_number LIKE '$tmpPrefix%' AND username='$username'";
	$sth = $dbh->prepare("$sql") or warn "###sth failed\n";
	$sth->execute() or die errmsg("###Transactions tbl failed") if $username;

$::Tag->tag({ op => 'header', body => <<EOB });
Status: 302 moved
Location: $redirecturl
EOB
	   return %result;
}

####----------------Handle the callback from Worldpay--------------####
elsif ($worldpayrequest eq 'callback'){

	my $newsess = $Vend::Session->{id};	
#::logDebug("WP:".__LINE__.": Processing Callback Session = $newsess");

	my $reporttitle   = charge_param('reporttitle') || '';
	my $update_status = charge_param('update_status') || 'pending';
	my $dec_inventory = charge_param('dec_inventory') || '';

#Capture all callback fields 
 	my ($transid, $check_testmode, $transstatus, $authamount, $transtime, $authcurrency, $rawauthcode, $rawauthmessage, $callbackpw,	$cardtype, $countrymatch, $avs, $wafmerchmessage, $authentication, $ipaddress, $wp_order_number);
	my $page = ::http()->{'entity'};
#::logDebug("WP".__LINE__.": page=\n$$page\n----------------------------------\n");
	foreach my $line (split /\&/, $$page) {
	  $transid		    = $1 if ($line =~ /transId=(.*)/i);			#transaction ID
	  $wp_order_number  = $1 if ($line =~ /MC_mv_order_number=(.*)/);# temp CartID sent
	  $check_testmode	= $1 if ($line =~ /testMode=(.*)/);			#returns testmode value 0 live anything higher test mode
	  $transstatus		= $1 if ($line =~ /transStatus=(.*)/); 		#Y=Sucess C=Cancelled
	  $authamount		= $1 if ($line =~ /authAmount=(.*)/);		#Authorised amount
	  $transtime		= $1 if ($line =~ /transTime=(.*)/);		#Time of transaction
	  $authcurrency		= $1 if ($line =~ /authCurrency=(.*)/);		#Currency of authorisation
	  $callbackpw		= $1 if ($line =~ /callbackPW=(.*)/);		#Callback password as set in admin panel
	  $rawauthmessage	= $::Values->{'rawauthmessage'}  = $1 if ($line =~ /rawAuthMessage=(.*)/);	#Raw auth message
	  $rawauthcode		= $::Values->{'rawauthcode'}     = $1 if ($line =~ /rawAuthCode=(.*)/);	#Raw auth message
	  $cardtype			= $::Values->{'cardtype'}        = $1 if ($line =~ /cardType=(.*)/);	#Card type used
	  $countrymatch		= $::Values->{'countrymatch'}    = $1 if ($line =~ /countryMatch=(.*)/); #Y=Match N=No match B=Not available I=Country not supplied S=Country issue not available
	  $avs			    = $::Values->{'avs'}             = $1 if ($line =~ /AVS=(.*)/);			#AVS Results
	  $wafmerchmessage	= $::Values->{'wafmerchmessage'} = $1 if ($line =~ /wafMerchMessage=(.*)/);	#Risk result
	  $authentication	= $::Values->{'authentication'}  = $1 if ($line =~ /authentication=(.*)/);	#VbyV or Mastercard Securecode authentication type
	  $ipaddress		= $::Values->{'ipaddress'}       = $1 if ($line =~ /ipAddress=(.*)/);		#Shopper IP address
   }
	  $::Values->{'cardtype'} = $cardtype =~ s/\+/ /g;
	  
#::logDebug("WP:".__LINE__.": transid=$transid testmode=$check_testmode transstatus=$transstatus authamount=$authamount transtime=$transtime authcurrency=$authcurrency rawauthmessage=$rawauthmessage");
#::logDebug("WP:".__LINE__.": callbackpw=$callbackpw cardtype=$cardtype countrymatch=$countrymatch avs=$avs wafmerchmessage=$wafmerchmessage authentication=$authentication ipaddress=$ipaddress");
 	
 	my $db  = Vend::Data::dbref('transactions') or die errmsg("cannot open transactions table");
	   $dbh = $db->dbh() or die errmsg("cannot get handle for tbl 'transactions'");

#::logDebug("WP:".__LINE__.": Callback order number = $wp_order_number");

#if success
  if (($transstatus eq 'Y') and ($callbackpw eq $callpw)) { 
#::logDebug("WP:".__LINE__.": Transaction Successful");

	   $sth = $dbh->prepare("SELECT total_cost,email,txtype,order_number FROM transactions WHERE order_number='$wp_order_number'") or die errmsg("Cannot select from transactions tbl for $wp_order_number");
	   $sth->execute() or die errmsg("Cannot get data from transactions tbl");
    my @d = $sth->fetchrow_array;
    my $order_total = $d[0];
    my $email       = $d[1];
    my $txtype      = $d[2];
    my $old_tid     = $d[3];
#generate the IC Order Number, and put in session to block old ICs from generating a second number
	my $new_order_no = $::Values->{mv_order_number} = $Vend::Session->{mv_order_number} = Vend::Interpolate::tag_counter("$ordernumber"); 
#Check if transaction was in test mode
    if ($check_testmode > '0') { # Transaction was in test mode
		$update_status = $update_status .'-TEST'; #Append Test to end of order status to show order was made in test mode
		$charged = $charged .'-TEST'; #Variable we write to txtype
		}    
#::logDebug("WP:".__LINE__.": new on = $new_order_no;  Check testmode = $check_testmode Update Status = $update_status Set txtype = $charged");
		
#Replace temporary order number with IC order number
#::logDebug("WP:".__LINE__.": Replacing order number: Old TID = $old_tid with New Order No = $new_order_no");
	   $sth = $dbh->prepare("UPDATE transactions SET code='$new_order_no', order_number='$new_order_no', txtype='$charged', payment_method='Worldpay ($cardtype)', cartid='$wp_order_number'  WHERE order_number='$wp_order_number'");
	   $sth->execute() or die errmsg("Cannot update transactions tbl for WP '$wp_order_number'");
	   $stho = $dbh->prepare("UPDATE orderline SET code=replace(code, '$old_tid', '$new_order_no'), order_number='$new_order_no' WHERE order_number='$old_tid'");
	   $stho->execute() or die errmsg("Cannot update transactions tbl for WP '$wp_order_number'");
	   
#Log transaction information & change order status
#::logDebug("WP:".__LINE__.": Logging transaction details to tbl for order $new_order_no");
	   $sth = $dbh->prepare("UPDATE transactions SET status='$update_status', order_id='$transid', wp_transtime='$transtime', wp_cardtype='$cardtype', wp_countrymatch='$countrymatch', wp_avs='$avs', wp_risk='$wafmerchmessage', wp_authentication='$authentication', wp_authamount='$authamount' WHERE order_number='$new_order_no'");
	   $sth->execute() or die errmsg("Cannot update transactions tbl for worldpay order '$new_order_no'");
	   $stho = $dbh->prepare("UPDATE orderline SET status='$update_status' WHERE order_number='$new_order_no'");
	   $stho->execute() or die errmsg("Cannot update orderline tbl for worldpay order '$new_order_no'");
	
#Read the order details and cart from the database
       $sth = $dbh->prepare("SELECT total_cost,email,order_number,fname,lname,company,address1,address2,city,state,zip,country,phone_day,fax,b_fname,b_lname,b_company,b_address1,b_address2,b_city,b_state,b_zip,b_country,shipmode,handling,order_date,lead_source,referring_url,txtype,locale,currency_locale,cart,session,salestax,shipping,b_phone,subtotal,cartid,email_copy,mail_list,free_sample FROM transactions WHERE order_number='$new_order_no'") or die errmsg("Cannot select from transactions tbl for $wp_order_number");
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
    my $shipmode = $::Values->{mv_shipmode} = $d[23];
    my $handling = $::Values->{mv_handling} = $d[24];
    my $order_date = $::Values->{order_date} = $d[25];
    my $lead_source = $::Values->{lead_source} = $d[26];
    my $referring_url = $::Values->{referring_url} = $d[27];
    my $txtype = $::Values->{txtype} = $d[28];
    my $mv_locale = $d[29];
    my $mv_currency = $d[30] || 'GBP';
    my $cart = $d[31];
    my $session = $d[32];
    my $salestax = $d[33] || '0';
    my $shipping = $d[34] || '0';
    my $phone_night = $::Values->{phone_night} = $d[35];
	my $subtotal = $d[36] || '0';
	my $cartID = $::Values->{'cartid'} = $d[37];
    my $email_copy = $::Values->{'email_copy'} = $d[38];
    my $mail_list = $::Values->{'mail_list'} = $d[39];
	my $free_sample = $::Values->{'free_sample'} = $d[40];
    
    #todo add evening phone
	   $::Values->{'mv_shipmode'} ||= 'Standard';
	   $::Values->{mv_handling} = 1 if ($handling > '0');
	   $cartID = $wp_order_number unless defined $cartID;
	   Vend::Interpolate::tag_assign({ subtotal => "$subtotal", shipping => "$shipping", salestax => "$salestax" });
	   Vend::Interpolate::tag_assign({ handling => "$handling" }) if ($handling > '0');
    
	my (@cart, $acart);
       $cart =~ s/\"/\'/g;
       $cart =~ s/\\//;
	   @cart = eval($cart); 
	   $acart = eval ($cart);
#::logDebug("WP:".__LINE__.": cart=$cart Email=$email");	
	   
	   $::Values->{mv_payment} = 'Worldpay'." $::Values->{'cardtype'}";
	   $::Values->{wp_order_number} = $wp_order_number;
	   $::Session->{values}->{iso_currency_code} = $currency;
	   $::Session->{scratch}->{mv_locale} = $mv_locale;
	   $::Session->{scratch}->{mv_currency} = $mv_currency;
	   $::CGI::values{'mv_todo'} = 'submit';
	   $result{'MStatus'} = $result{'pop.status'} = 'success';
	   $result{'order-id'} = $orderID;
	   $result{'Status'} = 'OK';
	   $result{'WPStatus'} = 'success';
	   $Vend::Session->{'payment_result'} = \%result;

 
#::logDebug("WP:".__LINE__.": Shipmode = $shipmode Shipping = $shipping Tax = $salestax Handling = $handling");


#Set new report title with final order number and WP transaction ID
	if ($reporttitle == '1') {
		my $amt = sprintf '%.2f', $order_total;
		$::Values->{mv_order_subject} = 'Order '.$new_order_no.' : CartID '.$cartID.' : WPID:'.$transid.' : '.$mv_currency.''.$amt.' : '.$charged;
	}       


	if ($dec_inventory == '1') {
#Decrement item quantities in inventory table
	my $dbi  = Vend::Data::database_exists_ref('inventory') or die errmsg("cannot open inventory table");
	my $dbhi = dbconnectwp() or die errmsg("cannot get handle for tbl 'inventory'");
	my ($sthi, $itm, $qty);
	
	foreach my $items (@{$acart})	{ 
		$itm = $items->{'code'};
		$qty = $items->{'quantity'};
		$sthi = $dbh->prepare("UPDATE inventory SET quantity = quantity -'$qty' WHERE sku = '$itm'");
		$sthi->execute() or die errmsg("Cannot update table inventory");
#::logDebug("WP:".__LINE__.": Decremented inventory for $itm by $qty");
	}
}

# run custom final route which cascades 'copy_user' and 'main_entry', ie no receipt page.
    	Vend::Order::route_order("wp_final", @cart) if @cart; 

		undef $Vend::Session->{mv_order_number};

#::logDebug("WP:".__LINE__.": sid=$::Session->{'id'};  End worldpay transaction success");
}

elsif ($callbackpw ne $callpw) { 
#This should never happen unless someone tries to simulate transactions without knowing the callback password or the password is entered incorrectly in catalog.cfg or the WP admin panel
#Transaction logged as txtype WP Pass Error and status passerror
#::logDebug("WP:".__LINE__.": Callback password was incorrect");
#::logDebug("WP:".__LINE__.": Logging transaction with callback password failure to tbl for order $wp_order_number");
	$sql = "DELETE FROM transactions WHERE order_number='$wp_order_number'";
	$sth = $dbh->prepare("$sql") or warn "sth failed\n";
	$sth->execute() or die errmsg("Transactions tbl failed");
	$sql = "DELETE FROM orderline WHERE order_number='$wp_order_number'";
	$stho = $dbh->prepare("$sql") or warn "sth failed\n";
	$stho->execute() or die errmsg("Orderline tbl failed");
}

else {
#transaction has been cancelled
#::logDebug("WP:".__LINE__.": Transaction for order $wp_order_number was cancelled");

#log details of cancelled transaction & set archived to 1 so it won't show in admin panel
#::logDebug("WP:".__LINE__.": Deleting cancelled transaction details from tbl for order $wp_order_number");
#    $dbh = dbconnectwp() or warn "dbh failed\n";
	$sql = "DELETE FROM transactions WHERE order_number='$wp_order_number'";
	$sth = $dbh->prepare("$sql") or warn "sth failed\n";
	$sth->execute() or die errmsg("Transactions tbl failed");
	$sql = "DELETE FROM orderline WHERE order_number='$wp_order_number'";
	$sth = $dbh->prepare("$sql") or warn "sth failed\n";
	$sth->execute() or die errmsg("Orderline tbl failed");
	
#	$Vend::Session->{'payment_result'}{'MStatus'} = 'cancelled';
	}

  }
	
}

package Vend::Payment::Worldpay;

1;

