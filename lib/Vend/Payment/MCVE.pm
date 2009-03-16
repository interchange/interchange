# Vend::Payment::MCVE - Interchange MCVE support
#
# $Id: MCVE.pm,v 1.6 2009-03-16 19:34:01 jon Exp $
#
# Author: Tom Friedel (tom@readyink.com) for Carlc Internet Services (http://www.carlc.com)
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

package Vend::Payment::MCVE;

use vars qw($VERSION);
$VERSION = substr(q$Revision: 1.6 $, 10);

=head1 NAME

Vend::Payment::MCVE - Interchange MCVE support

=head1 SYNOPSIS

    &charge=mcve

	or

    [charge mode=mcve param1=value1 param2=value2]

	or

    mcve($mode, $opt);

=head1 PREREQUISITES

    MCVE.pm

The MCVE libraries are available free at http://www.mcve.com/

=head1 DESCRIPTION

MCVE, Mainstreet Credit Verification Engine is a high performance
software application designed to provide quality, in-house, Credit Card
processing FROM Linux, FreeBSD, OpenBSD, IBM AIX, Sun Solaris, SCO
OpenServer/UnixWare, and Mac OS X platforms to established clearing
houses.  The MCVE C & Perl library software can be downloaded free of charge
from http://mcve.com.  This module was developed and tested with the server 
software installed on HotConnect.net (http://www.hotconnect.net). 
Hot Connect, Inc. is an Interchange friendly Web Hosting, E-Commerce, and
Internet Services company.

The Vend::Payment::MCVE module implements the mcve() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::MCVE

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<mcve>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  mcve

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge mode=mcve name=mcve_configname]

or

    Route mcve name mcve_configname

or 

    Variable MV_PAYMENT_NAME      mcve_configname

The active settings are:

    Variable   MV_PAYMENT_MODE mcve
    Variable   MV_PAYMENT_NAME mcve_username
    Variable   MV_PAYMENT_PASSWD mcve_password
    Variable   MV_PAYMENT_HOST sv1.carlc.com
    Variable   MV_PAYMENT_PORT 8333
    Variable   MV_PAYMENT_COUNTER etc/mcve_id.counter
    Variable   MV_PAYMENT_COUNTER_START 100
    Variable   MV_PAYMENT_SALE_ON_AUTH 1
    Variable   MV_PAYMENT_NO_SALE_BAD_AVS 0
    Variable   MV_PAYMENT_NO_SALE_BAD_CVV2 0
    Variable   MV_PAYMENT_SUCCESS_ON_ANY 0

=over 4

=item name

Your MCVE configuration username, set up when MCVE was configured/installed on
the machine. Global parameter is MV_PAYMENT_NAME.

=item no_sale_bad_avs

Normally Interchange charge modules do an authorization, and if successful, do a sale.
This module is configurable for a different models, where transactions are not
automatically saled.  

=item sale_on_auth

The storekeeper may not wish to sale a transaction if the AVS is bad.  

=item success_on_any

Alternatively the storekeeper may wish to cause any transaction to appear to be a
successful sale.  The storekeeper would have to contact buyers with bad credit card
information and manually redo the sale.  The motivation is to make sure no one
attempts a sale and gives up for any reason.   This mode of operation, set with
MV_PAYMENT_SUCCESS_ON_ANY is not commonly used.

=item transaction

The type of transaction to be run. Valid values are:

    Interchange mode    MCVE mode
    ----------------    -----------------
    auth                auth
    sale                sale

Not supported yet:

    return              return
    reverse             reverse
    void                void

=item counter, counter_start

Currently this is not being used, and Interchange is generating id's.

    Route   mcve  counter        etc/mcve_id.counter
    Route   mcve  counter_start  100

=back

=head2 Troubleshooting

Try the instructions above, with a test credit card number from your payment processor.

Then try a sale with the card number C<4111 1111 1111 1111>
and a valid expiration date. The sale should be denied, and the reason should
be in [data session payment_error].

If nothing works:

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::MCVE

Make sure MCVE is installed and working.

Check the error logs, both catalog and global.

Make sure you set your payment parameters properly.  

Try an order, then put this code in a page:

    [calc]
	$Tag->uneval( { ref => $Session->{payment_result} );
    [/calc]

That should show what happened.

=head1 BUGS

There is actually nothing *in* Vend::Payment::MCVE. It changes packages
to Vend::Payment and places things there.

=head1 AUTHORS

MCVE modifications by tom@readyink.com for Carlc Internet Services

=head1 CREDITS

Derived from CCVS.pm template, and others.

=cut

BEGIN {
	eval {
		package Vend::Payment;
        	require MVCE or die __PACKAGE__ . " requires MVCE";
		::logGlobal({}, "MCVE module found version %s", $MCVE::VERSION)
			unless $Vend::Quiet or ! $Global::VendRoot;
	};

	::logGlobal("%s payment module %s initialized", __PACKAGE__, $VERSION)
		unless $Vend::Quiet or ! $Global::VendRoot;
}

package Vend::Payment;

sub mcve {
    my ($opt) = @_;

#::logDebug("mcve called, args=" . ::uneval(\@_));

    my $sess;
    my %result;

    my $mcve_die = sub {
	my ($msg, @args) = @_;
	$msg = "MCVE: $msg" unless $msg =~ /^MCVE/;
	$msg = ::errmsg($msg, @args);
	&MCVE::done($sess) if $sess;
	::logDebug("mcve erred, result=$msg");
	die("$msg\n");
    };

    my $actual = $opt->{actual};
    if(! $actual) {
	my %actual = map_actual();
	$actual = \%actual;
    }

    if(! defined $opt->{precision} ) {
        $opt->{precision} = charge_param('precision');
    }

    my $exp = sprintf '%02d%02d',
    $actual->{mv_credit_card_exp_month},
    $actual->{mv_credit_card_exp_year};

    my $op = $opt->{transaction} || 'sale';

    my %type_map = (
	mauthcapture	=>	'sale',
	mauthonly	=>	'auth',
	mauthreturn	=>	'return',
	S		=>	'sale',
	C		=>	'auth',
	V		=>	'void',
	sale		=>	'sale',
	auth		=>	'auth',
	authorize	=>	'auth',
	void		=>	'void',
	delete		=>	'delete',
    );

    if (defined $type_map{$op}) {
        $op = $type_map{$op};
    }

    if(! $amount) {
        $amount = $opt->{total_cost} || 
	  Vend::Util::round_to_frac_digits(
					 Vend::Interpolate::total_cost(),
					   $opt->{precision},
					   );
    }

    my $invoice;

    unless ($invoice = $opt->{order_id}) {

	if($op ne 'auth' and $op ne 'sale') {
	    return $mcve_die->("must supply order ID for transaction type %s", $op);
	}

	my $file =  $opt->{"counter"} || charge_param('counter');
	$file = "etc/mcve_order.counter" if ! $file ;

	if ( open( FILE, $file  )) {
	    $orderID = <FILE> ;
	    close( FILE ) ;
	    chomp $orderID ;
	    $orderID ++ ;
	}
	else {
	    $orderID = $opt->{"counter_start"} || charge_param('counter_start') || 100 ;
	}

	if ( open( FILE, ">$file" )) {
	    print FILE "$orderID\n" ;
	    close( FILE ) ;
	}
	else {
	    return $mcve_die->("Could not create OrderID file $file");
	}
	$invoice = $orderID ;
    }

    $cvv2 = "" ;

    $configname =  $opt->{"name"} || charge_param('name');
    ::logDebug("mcve configuration name '$configname'");

    $mcve_id = $configname ;
    $mcve_pw = $opt->{"passwd"} || charge_param('passwd');
    ::logDebug("mcve configuration pw '$mcve_pw'");

    $host = $opt->{"host"} || charge_param('host');
    ::logDebug("mcve configuration host '$host'");

    $port = $opt->{"port"} || charge_param('port');
    ::logDebug("mcve configuration port '$port'");

    $host = "sv1.carlc.com" if ! $host ;
    $port = 8333 if ! $port ;

    $mcve_sale_on_auth = 1 ;
    $mcve_sale_on_auth = $opt{"sale_on_auth"} || charge_param('sale_on_auth') ;

    $mcve_no_sale_bad_avs = 0 ;
    $mcve_no_sale_bad_avs = $opt{"no_sale_bad_avs"} || charge_param('no_sale_bad_avs') ;

    $mcve_no_sale_bad_cvv2 = 0 ;
    $mcve_no_sale_bad_cvv2 = $opt{"no_sale_bad_cvv2"} || charge_param('no_sale_bad_cvv2') ;

    $mcve_success_on_any = 0 ;
    $mcve_success_on_any = $opt{"success_on_any"} || charge_param('success_on_any') ;

    $conn=MCVE::MCVE_InitConn();

    ::logDebug("Connected\n");

    &MCVE::MCVE_SetIP($conn, $host, $port);
    ::logDebug("Set IP\n");

    if ( &MCVE::MCVE_Connect($conn) == 0) {

	::logDebug("Count not Connect\n");

	&MCVE::MCVE_DestroyConn($conn);
	&MCVE::MCVE_DestroyEngine();
	return $mcve_die->("MCVE Connection Failed");
    }

    ::logDebug("Op = $op\n");

    if($op eq 'auth' or $op eq 'sale') {

	$cvv2 = "" ;
	$zip = $actual->{b_zip} ;
	$address = $actual->{"b_address"} ;

## These is specific to HotConnect MCVE implementation
	$comments = $actual->{"b_fname"} . " " . $actual->{"b_lname"} . "|" . $actual->{"b_address"} ;
	$clerkid = "" ;
	$stationid = 0 ;

	$text = "" ;
	$trackdata = "" ;
	$cardno = $actual->{"mv_credit_card_number"} ;

	::logDebug("Before PreAuth\n");

	$identifier=&MCVE::MCVE_PreAuth($conn, $mcve_id, $mcve_pw, $trackdata, $cardno, $exp, $amount, $address, $zip, $cvv2, $comments, $clerkid, $stationid, '');

	if ($identifier == MCVE::MCVE_ERROR()) {

	    ::logDebug("PreAuth Error\n");

	    &MCVE::MCVE_DestroyConn($conn);
	    &MCVE::MCVE_DestroyEngine();
	    return $mcve_die->("Error Making Transaction %s", $configname);
	}

	my $cnt = 0 ;
	while (&MCVE::MCVE_CheckStatus($conn, $identifier) != &MCVE::MCVE_DONE()) { # Wait until this transaction is done....
	    &MCVE::MCVE_Monitor($conn); # MCVE_Monitor does the actual background communication with the MCVE daemon via IP or SSL
	    sleep(1);		# Don't loop too fast :)
	    $cnt ++ ;
	    if ( $cnt == 100 ) {
		return $mcve_die->("CheckStatus Time Out %s", $configname);
	    }
	}

	$decline = 0 ;
	if (&MCVE::MCVE_ReturnStatus($conn, $identifier) == &MCVE::MCVE_SUCCESS()) {
	    $acode = MCVE::MCVE_TransactionAuth($conn, $identifier); #  Authorization Number
	    $sid = MCVE::MCVE_TransactionID($conn, $identifier); #  Authorization Number
	    $result{"pop.error_message"} = $result{"result_text"} = "success" ;
	    $result{"pop.auth-code"} = $acode ;
	} else {
	    $decline = 1 ;
	    $text = MCVE::MCVE_TransactionText($conn, $identifier);
	    $text = "Your card was declined ($text)" ;
	    $result{"pop.error_message"} = $result{"result_text"} = $text ;

	    my $msg = errmsg(
			     "MCVE error: %s %s. Please call in your order or try again.",
			     $result{MStatus},
			     $result{result_text},
			     );
	    $Vend::Session->{errors}{mv_credit_card_valid} = $msg;
	}


	$avs = MCVE::MCVE_TransactionAVS($conn, $identifier);
	$result{"pop.avs_code"} = $avs ;

	$cv = MCVE::MCVE_TransactionCV($conn, $identifier);

	if ( ! $decline && ( $op eq "sale" ) && $mcve_sale_on_auth ) {

## cv = -1 if not entered, 0 if bad, 1 if good
## avs = -1 if not entered, 0 if bad, 1 or 2 or 3 if address/zip match
	    if ((( $avs > 0 ) || ! $mcve_no_sale_bad_avs ) && (($cvv2 && ( $cv > 0 )) || ! $mcve_no_sale_bad_cvv2 )) {

		$identifier=&MCVE::MCVE_PreAuthCompletion($conn, $mcve_id, $mcve_pw, $amount, $sid, '' ) ;

		if ($identifier == MCVE::MCVE_ERROR()) {
		    &MCVE::MCVE_DestroyConn($conn);
		    &MCVE::MCVE_DestroyEngine();
		    return $mcve_die->("Error Forcing Transaction ($acode)");
		}

		while (&MCVE::MCVE_CheckStatus($conn, $identifier) != &MCVE::MCVE_DONE()) { # Wait until this transaction is done....
		    &MCVE::MCVE_Monitor($conn); # MCVE_Monitor does the actual background communication with the MCVE daemon via IP or SSL
		    sleep(1);	# Don't loop too fast :)
		}

		if (&MCVE::MCVE_ReturnStatus($conn, $identifier) == &MCVE::MCVE_SUCCESS()) {
#		$text .= "AVS Response = $avs - CV Response = $cv" ;
		    $decline = 0 ;
		} else {
		    $decline = 1 ;
		    $text= "Force: " . &MCVE::MCVE_TransactionText($conn, $identifier);
		}
	    }

	}

	$result{"order-id"} =  $result{"pop.order-id"} = $invoice ;

	if ( $mcve_success_on_any ) {
	    $decline = 0 ;
	}

	# If everything was succesful, push through the sale.
	if (! $decline) {
	    $result{'pop.status'} =	    $result{MStatus} = 'success';
	    $result{'invoice'} = $invoice;
	}
	else  {			#decline
	    $result{MStatus} = 'failed';
	    my $msg = errmsg(
			     "MCVE error: %s %s. Please call in your order or try again.",
			     $result{MStatus},
			     $result{result_text},
			     );
	    $Vend::Session->{errors}{mv_credit_card_valid} = $msg;
	}
    }

    &MCVE::MCVE_DestroyConn($conn);
    &MCVE::MCVE_DestroyEngine();

#::logDebug("mcve returns, result=" . ::uneval(\%result));
    return %result;
}

package Vend::Payment::MCVE;

1;
