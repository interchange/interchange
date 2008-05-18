# Vend::Payment::BoA - Interchange BoA support
#
# $Id: BoA.pm,v 1.15 2007-08-09 13:40:55 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1999-2002 Red Hat, Inc.
#
# by Mark Johnson based off of AuthorizeNet.pm by
# mark@summersault.com
# Mike Heins
# webmaster@nameastar.net
# Jeff Nappi <brage@cyberhighway.net>
# Paul Delys <paul@gi.alaska.edu>

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


# Connection routine for BoA's eStore payment gateway

package Vend::Payment::BoA;

=head1 NAME

Vend::Payment::BoA - Interchange Bank of America Support

=head1 SYNOPSIS

    &charge=boa
 
        or
 
    [charge mode=boa param1=value1 param2=value2]

=head1 PREREQUISITES

  Net::SSLeay
 
    or
  
  LWP::UserAgent and Crypt::SSLeay

Only one of these need be present and working.

=head1 DESCRIPTION

The Vend::Payment::BoA module implements the boa() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules -- in theory (and even usually in practice) you
could switch from CyberCash to BoA with a few configuration file changes.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::BoA

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<boa>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  boa

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge mode=boa id=YourBoAID]

or

    Route boa id YourBoAID

or 

    Variable MV_PAYMENT_ID      YourBoAID

The active settings are:

=over 4

=item id

Your BoA merchant_id (ioc_merchant_id), supplied by BoA when you sign up.
Global parameter is MV_PAYMENT_ID.

=item transaction

Type of transaction to execute. May be:

  authorize - Perform authorization only (default)
  sale      - Authorize and settle (requires two separate requests)
  settle    - Perform settlement only on previously authorized transaction
  return    - Make a refund on previously settled transaction

Global parameter is MV_PAYMENT_TRANSACTION

=item referer

The url of the web page you are posting from, required by BoA
Global parameter is MV_PAYMENT_REFERER

=item accept

The return codes for which you consider a credit card acceptable, comma separated.
Codes are:

 
  -1   "Faith" authorization. (See http://www.bofa.com/merchantservices/index.cfm?template=merch_ic_estores_developer.cfm#table5 for details)
   0    Order authorized.
   1    Some other failure. Try again.
   2    Card Declined.  Do not accept the order.
   3    No response from issuing institution.  Try again.
   4    Bad card.  Do not accept the order. Merchant should call shopper
   5    Error in transfer amount.
   6    Credit card expired.
   7    Transaction is invalid.
   8    Unknown system error.
   9    Duplicate request.  This transaction was completed earlier.
   >=10 Other error.  Contact you merchant bank representative.

Default is to accept for return code <= 0.
'accept' codes only valid on authorize transaction. All others only successful with
return code of 0.

Global parameter is MV_PAYMENT_ACCEPT

        Ex: Variable MV_PAYMENT_ACCEPT -1,0,1,3,8,10

=item timeout_error

The error displayed if Bank of America is not responding, or is down.
Default is "Credit card processor not responding. Please try again later or call our customer service directly".

Global parameter is MV_PAYMENT_TIMEOUT_ERROR

=item username

userid used to log in to Back Office (not needed for authorization only)

Global parameter is MV_PAYMENT_USERNAME

=item secret

password used to log in to Back Office (not needed for authorization only)

Global parameter is MV_PAYMENT_SECRET

=head2 Troubleshooting

Try the instructions above, then enable test mode in the online
account manager. A test order should complete.

Disable test mode, then test in various BoA error modes by
using the credit card number 4222 2222 2222 2222.

Then try a sale with the card number C<4111 1111 1111 1111>
and a valid expiration date. The sale should be denied, and the reason should
be in [data session payment_error].

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::BoA

=item *

Make sure either Net::SSLeay or Crypt::SSLeay and LWP::UserAgent are installed
and working. You can test to see whether your Perl thinks they are:

    perl -MNet::SSLeay -e 'print "It works\n"'

or

    perl -MLWP::UserAgent -MCrypt::SSLeay -e 'print "It works\n"'

If either one prints "It works." and returns to the prompt you should be OK
(presuming they are in working order otherwise).

=item *

Check the error logs, both catalog and global.

=item *

Make sure you set your payment parameters properly.  

=item *

Try an order, then put this code in a page:

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

If all else fails, consultants are available to help
with integration for a fee. See http://www.icdevgroup.org/

=back

=head1 BUGS

There is actually nothing *in* Vend::Payment::BoA. It changes packages
to Vend::Payment and places things there.

=head1 AUTHORS

Mark Johnson, based on original code by Mike Heins.

=head1 CREDITS

    Jeff Nappi <brage@cyberhighway.net>
    Paul Delys <paul@gi.alaska.edu>
    webmaster@nameastar.net
    Ray Desjardins <ray@dfwmicrotech.com>
    Nelson H. Ferrari <nferrari@ccsc.com>

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
			import HTTP::Request::Common qw(POST);
			$selected = "LWP and Crypt::SSLeay";
		};

		$Vend::Payment::Have_LWP = 1 unless $@;

	}

	unless ($Vend::Payment::Have_Net_SSLeay or $Vend::Payment::Have_LWP) {
		die __PACKAGE__ . " requires Net::SSLeay or Crypt::SSLeay";
	}

	::logGlobal("%s payment module initialized, using %s", __PACKAGE__, $selected)
		unless $Vend::Quiet or ! $Global::VendRoot;

}

package Vend::Payment;
sub boa {
	my ($user, $amount) = @_;

	my $opt;
	if(ref $user) {
		$opt = $user;
		$user = $opt->{id} || undef;
	}
	else {
		$opt = {};
	}
	
	my $actual;

	if($opt->{actual}) {
		$actual = $opt->{actual};
	}
	else {
		my (%actual) = map_actual();
		$actual = \%actual;
	}

#::logDebug("actual map result: " . ::uneval($actual));
	if (! $user ) {
		$user    =  charge_param('id')
						or return (
							MStatus => 'failure-hard',
							MErrMsg => errmsg('No account id'),
							);
	}
	
	my $referer   = $opt->{referer} || charge_param('referer');

	if (! $referer ) {
		return (
			MStatus => 'failure-hard',
			MErrMsg => errmsg('No referer domain or IP specified'),
			);
	}

	$opt->{host}   ||= 'cart.bamart.com';

	$opt->{port}   ||= 443;

	my $precision = $opt->{precision} || 2;

	my $timeout_error = $opt->{timeout_error} ||
			charge_param('timeout_error') ||
			q!Credit card processor not responding. Please try again later or call our customer service directly.!;

    # Using mv_payment_mode for compatibility with older versions, probably not
    # necessary. Modes are 'authorize', 'settle', and 'return'. Default is
    # 'authorize'. 'sale' is used as a combined hit, first authing, and then
    # settling.

    my %type_map = (
		auth		 		=> 'authorize',
		authorize		 	=> 'authorize',
		mauthonly			=> 'authorize',
		mauthcapture 			=> 'sale',
		sale		 		=> 'sale',
		return				=> 'return',
		mauthreturn			=> 'return',
		settle      			=> 'settle',
		settle_prior      		=> 'settle'
	);

    my $transtype = $opt->{transaction} ||
			charge_param('transaction') ||
			'authorize';

    $transtype = $type_map{ $transtype }
			or return (
				MStatus => 'failure-hard',
				MErrMsg => errmsg('Invalid transaction type "%s"', $transtype ),
				);

    $order_id = gen_order_id($opt);

#::logDebug("transtype: $transtype");

    $opt->{script} = '/payment.mart';
	 
    # Phone less than 17 chars, and country must be US, not USA.
    $actual->{ 'phone_day' } = substr( $actual->{ 'phone_day' }, 0, 16 );
    $actual->{ 'b_country' } = 'US' if $actual->{ 'b_country' } eq 'USA';

    $actual->{mv_credit_card_exp_month} =~ s/\D//g;
    $actual->{mv_credit_card_exp_month} =~ s/^0+//;
    $actual->{mv_credit_card_exp_year} =~ s/\D//g;
    unless ($actual->{mv_credit_card_exp_year} =~ s/^\s*(\d{4})\s*$/$1/ ) {
    	my $boa_passed_year = int( $actual->{mv_credit_card_exp_year} );
    	my $boa_current_year = POSIX::strftime('%Y',localtime(time));
    	my ($boa_century, $boa_current_year) = $boa_current_year =~ /^(\d{2})(\d{2})$/;
    	$boa_century *= 100;
    	$boa_century += 100 if $boa_passed_year < $boa_current_year;
    	$actual->{mv_credit_card_exp_year} = $boa_century + $boa_passed_year;
    }
    $actual->{mv_credit_card_number} =~ s/\D//g;

    $amount = $opt->{total_cost} if $opt->{total_cost};
    
    if(! $amount) {
    	$amount = Vend::Interpolate::total_cost();
    	$amount = Vend::Util::round_to_frac_digits($amount,$precision);
    }

    my $boa_accept_string = $opt->{accept} =~ /\d/ ? $opt->{accept} : charge_param('accept');
    my %boa_accept_map;
    if ($boa_accept_string =~ /\d/) {
    	$boa_accept_string =~ s/\s+//g;
    	@boa_accept_map{ split(/,/, $boa_accept_string) } = ();
    }
    else {
    	@boa_accept_map{qw/-1 0/} = ();
    } 

    my %query = (
        IOC_order_total_amount		=> $amount,
        IOC_merchant_id			=> $user,
        IOC_merchant_shopper_id		=> $opt->{merchant_shopper_id} ||
    						charge_param('merchant_shopper_id'),
        IOC_merchant_order_id		=> $actual->{order_id} || $order_id,
        Ecom_billto_postal_name_first	=> $actual->{b_fname},
        Ecom_billto_postal_name_last	=> $actual->{b_lname},
        Ecom_billto_postal_street_line1	=> $actual->{b_address1},
        Ecom_billto_postal_street_line2	=> $actual->{b_address2},
        Ecom_billto_postal_city		=> $actual->{b_city},
        Ecom_billto_postal_stateprov	=> $actual->{b_state},
        Ecom_billto_postal_countrycode	=> $actual->{b_country},
        Ecom_billto_telecom_phone_number	=> $actual->{phone_day},
        Ecom_billto_online_email		=> $actual->{email},
        Ecom_payment_card_name		=> $actual->{b_name} ||
    						$actual->{name},
        Ecom_billto_postal_postalcode	=> $actual->{b_zip},
        Ecom_payment_card_expdate_year	=> $actual->{mv_credit_card_exp_year},
        Ecom_payment_card_expdate_month	=> $actual->{mv_credit_card_exp_month},
        Ecom_payment_card_number		=> $actual->{mv_credit_card_number},
    );

    if ($transtype =~ /^(?:settle|return)/)  {

	$opt->{script} = '/settlement.mart';
	my %indicator = qw/settle S return R/;
	%query = (
	   IOC_handshake_id		=> $opt->{handshake_id} ||
						charge_param('handshake_id') ||
						$order_id,
	   IOC_merchant_id		=> $user,
	   IOC_user_name		=> $opt->{username} ||
						charge_param('username'),
	   IOC_password			=> $opt->{secret} ||
						charge_param('secret'),
	   IOC_order_number		=> $opt->{ioc_order_id},
	   IOC_indicator		=> $indicator{ $transtype },
	   IOC_settlement_amount	=> $opt->{total_cost},
	   IOC_authorization_code	=> $opt->{authorization_code},
	);
    }

#::logDebug("BoA query: " . ::uneval(\%query));

    $opt->{extra_headers} = { Referer => $referer };

    my $call_gateway = sub {
	my ($opt,$query) = @_;
	my $thing    = post_data($opt, $query);
	my $page     = $thing->{result_page};
	my $response = $thing->{status_line};

#::logDebug("BoA post_data response: " . ::uneval($thing) );
	
	my %result;
	my $sep = "<br>";

	$page =~ s/\r*<html>.*$//is;

	foreach ( split( /$sep/i, $page) ) {
		my ($key, $value) = split (/=/, $_, 2);
		$value =~ tr/+/ /;
		$value =~ s/%([0-9a-fA-F]{2})/chr( hex( $1 ) )/ge;
		$result{$key} = $value;
		$result{"\L$key"} = $value;
	}


#::logDebug("BoA result hash: " . ::uneval(\%result) );

	return %result;
    };

    my %result = $call_gateway->($opt,\%query);

    if ($transtype =~ /^(?:auth|sale)/) {
	# Interchange names are on the left, BoA on the right
	my %result_map = ( qw/
            pop.status            ioc_response_code
            pop.error-message     ioc_reject_description
            order-id              ioc_shopper_id
            pop.order-id          ioc_shopper_id
            pop.auth-code         ioc_authorization_code
            pop.avs_code          ioc_avs_result
	    /
	);

	for (keys %result_map) {
		$result{$_} = $result{$result_map{$_}}
			if defined $result{$result_map{$_}};
	}

#::logDebug(qq{BoA %result after result_map loop:\n} . ::uneval(\%result));

	if (exists $boa_accept_map{ $result{ioc_response_code} } ) {
		$result{MStatus} = 'success';
		$result{'order-id'} ||= $opt->{order_id};
	}
	else {
		$result{MStatus} = 'failure';
		delete $result{'order-id'};

		my $msg = $opt->{message_declined} ||
			"BoA payment error: %s";
		$result{MErrMsg} = errmsg($msg, $result{ioc_reject_description} || $timeout_error);
		return (%result);
	}
    }

    if ($transtype =~ /^sale/) {
	$opt->{script} = '/settlement.mart';
	my %query = (
	   IOC_handshake_id		=> $query{IOC_merchant_order_id},
	   IOC_merchant_id		=> $user,
	   IOC_user_name		=> $opt->{username} ||
						charge_param('username'),
	   IOC_password			=> $opt->{secret} ||
						charge_param('secret'),
	   IOC_order_number		=> $result{ioc_order_id},
	   IOC_indicator		=> 'S',
	   IOC_settlement_amount	=> $amount,
	   IOC_authorization_code	=> $result{ioc_authorization_code}
	);

#::logDebug("BoA sale query: " . ::uneval(\%query));

	my %sale_result = $call_gateway->($opt,\%query);

	foreach (keys %sale_result) {
		$result{$_} = $sale_result{$_}
			unless exists $result{$_};
	}

        $sale_result{ioc_response_code} =~ s/\s+//g;
	if ( $sale_result{ioc_response_code} != 0) {
		$result{MStatus} = 'failure';
		delete $result{'order-id'};

		my $msg = "BoA payment error: authorization passed but settlment failed with code %s: %s Please contact customer service or try a different card.";
		$result{MErrMsg} = errmsg($msg, @sale_result{qw/ioc_response_code ioc_response_desc/});
	}
    }

    elsif ($transtype =~ /^(?:settle|return)/) {
	$result{ioc_response_code} =~ s/\s+//g;
	if ( $result{ioc_response_code} != 0) {
		$result{MStatus} = 'failure';
		my $msg = "BoA payment error: transaction failed with code %s: %s";
		$result{MErrMsg} = errmsg($msg, @result{qw/ioc_response_code ioc_response_desc/});
	}
	else {
		$result{MStatus} = 'success';
	}
    }
    return (%result);
}

package Vend::Payment::BoA;

1;
