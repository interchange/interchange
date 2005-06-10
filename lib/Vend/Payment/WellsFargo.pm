# Vend::Payment::WellsFargo - Interchange WellsFargo support
#
# $Id: WellsFargo.pm,v 1.8 2005-06-10 10:54:33 docelic Exp $
#
# Copyright (C) 2002-2003 Interchange Development Group
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
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

# Connection routine for WellsFargo's eStore payment gateway

package Vend::Payment::WellsFargo;

=head1 NAME

Vend::Payment::WellsFargo - Interchange WellsFargo Support

=head1 SYNOPSIS

    &charge=wellsfargo
 
        or
 
    [charge mode=wellsfargo param1=value1 param2=value2]

=head1 PREREQUISITES

  Net::SSLeay
 
    or
  
  LWP::UserAgent and Crypt::SSLeay

Only one of these need be present and working.

=head1 DESCRIPTION

The Vend::Payment::WellsFargo module implements the wellsfargo() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules -- in theory (and even usually in practice) you
could switch from CyberCash to WellsFargo with a few configuration file changes.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::WellsFargo

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<wellsfargo>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  wellsfargo

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge mode=wellsfargo id=YourWellsFargoID]

or

    Route wellsfargo id YourWellsFargoID

or 

    Variable MV_PAYMENT_ID      YourWellsFargoID

The active settings are:

=over 4

=item id

Your WellsFargo merchant_id (ioc_merchant_id), supplied by WellsFargo when you sign up.

Global parameter is MV_PAYMENT_ID.

=item transaction

Type of transaction to execute. May be:

  authorize - Perform authorization only (default)
  sale      - Authorize and settle (requires two separate requests)
  settle    - Perform settlement only on previously authorized transaction
  return    - Make a refund on previously settled transaction

Global parameter is MV_PAYMENT_TRANSACTION

=item referer

The url of the web page you are posting from, required by WellsFargo
Global parameter is MV_PAYMENT_REFERER

=item accept

The return codes for which you consider a credit card acceptable, comma separated.
Codes are:

 
  -1   "Faith" authorization.
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

The error displayed if WellsFargo is not responding, or is down.
Default is "Credit card processor not responding. Please try again later or call our customer service directly".

Global parameter is MV_PAYMENT_TIMEOUT_ERROR

=item custom_query

Key of scratch hash containing additional name/value pairs. Use for
any optional fields you wish to pass to the gateway (optional as
defined by developer docs). For example, to "close an order" on a
settlement, you can pass the IOC_close_flag parameter to the
gateway. So, to utilize this feature, set a scratch hash,
keyed by param C<custom_query>.

For mode config:
  Route  wellsfargo  custom_query  my_cust_query

Before calling wellsfargo(), set in scratch:

  $Scratch->{my_cust_query} = {
	IOC_close_flag => 'Yes'
  };

Keys in custom_query will also supersede any pre-existing
parameters, if needed. Thus, if you wish to collect and
pass the actual Card Verification Number from customer
cards, with a form field named C<cc_verification_number>:

  $Scratch->{my_cust_query} = {
	Ecom_payment_card_verification => $Values->{cc_verification_number}
  };

Care should be taken not to accidentally overwrite desired
pre-existing parameters.

C<custom_query> hash will be deleted from scratch space after
each call to wellsfargo().

Note: since a C<sale> operation is actually two independent requests
to the gateway, with each having different queries for the most
part, be aware that any defined custom_query will be sent in
both requests--and override any same-named parameters in both.

=item username

Valid API-user userid set in Back Office (not needed for authorization only)

Global parameter is MV_PAYMENT_USERNAME

=item secret

password for same API-user (not needed for authorization only)

Global parameter is MV_PAYMENT_SECRET

=head2 Troubleshooting

Try the instructions above, then enable test mode in the online
account manager. A test order should complete.

Disable test mode, then test in various WellsFargo error modes by
using the credit card number 4222 2222 2222 2222.

Then try a sale with the card number C<4111 1111 1111 1111>
and a valid expiration date. The sale should be denied, and the reason should
be in [data session payment_error].

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::WellsFargo

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

If all else fails, consultants are available to help with integration for a fee.
See http://www.icdevgroup.org/

=back

=head1 BUGS

There is actually nothing *in* Vend::Payment::WellsFargo. It changes packages
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
sub wellsfargo {
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

	$opt->{host}   ||= 'cart.wellsfargoestore.com';

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
		mauthcapture 		=> 'sale',
		sale		 		=> 'sale',
		return				=> 'return',
		mauthreturn			=> 'return',
		settle      		=> 'settle'
		settle_prior      	=> 'settle'
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

    $actual->{mv_credit_card_exp_month} =~ s/\D//g;
    $actual->{mv_credit_card_exp_month} =~ s/^0+//;
    $actual->{mv_credit_card_exp_year} =~ s/\D//g;
    unless ($actual->{mv_credit_card_exp_year} =~ s/^\s*(\d{4})\s*$/$1/ ) {
    	my $wellsfargo_passed_year = int( $actual->{mv_credit_card_exp_year} );
    	my $wellsfargo_current_year = POSIX::strftime('%Y',localtime(time));
    	my ($wellsfargo_century, $wellsfargo_current_year) = $wellsfargo_current_year =~ /^(\d{2})(\d{2})$/;
    	$wellsfargo_century *= 100;
    	$wellsfargo_century += 100 if $wellsfargo_passed_year < $wellsfargo_current_year;
    	$actual->{mv_credit_card_exp_year} = $wellsfargo_century + $wellsfargo_passed_year;
    }
    $actual->{mv_credit_card_number} =~ s/\D//g;

    $amount = $opt->{total_cost} if $opt->{total_cost};
    
    if(! $amount) {
    	$amount = Vend::Interpolate::total_cost();
    	$amount = Vend::Util::round_to_frac_digits($amount,$precision);
    }

    my $wellsfargo_accept_string = $opt->{accept} =~ /\d/ ? $opt->{accept} : charge_param('accept');
    my %wellsfargo_accept_map;
    if ($wellsfargo_accept_string =~ /\d/) {
    	$wellsfargo_accept_string =~ s/\s+//g;
    	@wellsfargo_accept_map{ split(/,/, $wellsfargo_accept_string) } = ();
    }
    else {
    	@wellsfargo_accept_map{qw/-1 0/} = ();
    } 

    my %query = (
	IOC_order_ship_amount		=> 0,
	IOC_order_tax_amount		=> 0,
        IOC_order_total_amount		=> $amount,
        IOC_merchant_id			=> $user,
        IOC_merchant_shopper_id		=> $opt->{merchant_shopper_id} ||
    						charge_param('merchant_shopper_id') ||
						$order_id,
        IOC_merchant_order_id		=> $actual->{order_id} || $order_id,
	IOC_shipto_same_as_billto	=> 1,
	IOC_order_transaction_type	=> 'credi',
	IOC_CVV_indicator		=> 1,
	IOC_buyer_type			=> 'I',
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
        Ecom_payment_card_number	=> $actual->{mv_credit_card_number},
        Ecom_payment_card_type		=> "\U$::Values->{mv_credit_card_type}",
        Ecom_payment_card_verification	=> 123,
    );

    my $sale = 0;
    if ($transtype =~ /^(?:settle|return)/)  {

	$sale = 1;
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

#::logDebug("WellsFargo query (before passed query params): " . ::uneval(\%query));

    # Adding in custom_query, if present
    my $extra = {};
    if ( ref( $Vend::Session->{scratch}->{ $opt->{custom_query} } ) =~ /HASH/ ) {
	$extra = delete $Vend::Session->{scratch}->{ $opt->{custom_query} };

	if ( scalar keys %$extra ) {
             my @new_keys = keys %$extra;
             @query{ @new_keys } = @{ $extra }{ @new_keys };
	}
    }

#::logDebug("WellsFargo query (after passed query params): " . ::uneval(\%query));

    $opt->{extra_headers} = { Referer => $referer };

    my $call_gateway = sub {
	my ($opt,$query,$sale) = @_;
	my $thing    = post_data($opt, $query);
	my $page     = $thing->{result_page};
	my $response = $thing->{status_line};
#::logDebug("WellsFargo post_data response: " . ::uneval($thing) );
	
	my %result;

	my $sep = '<br>';

	if ($sale) {
		$page =~ s/\r*<html>.*$//is;
		$sep = "\r+";
	}

	foreach ( split( /$sep/i, $page) ) {
		my ($key, $value) = split (/=/, $_, 2);
		$value =~ tr/+/ /;
		$value =~ s/%([0-9a-fA-F]{2})/chr( hex( $1 ) )/ge;
		$result{$key} = $value;
		$result{"\L$key"} = $value;
	}

#::logDebug("WellsFargo result hash: " . ::uneval(\%result) );

	return %result;
    };

    my %result = $call_gateway->($opt,\%query,$sale);

    #
    # Map for response codes when gateway does not provide its own response.
    #
    my $response_map = {
	1 => 'Authorization system not responding. Please retry transaction.',
	2 => 'Authorization declined. Please retry with different credit card.',
	3 => 'No response from issuing institution. Order not accepted. Please retry.',
	4 => 'Authorization declined. Invalid credit card. Please retry with different credit card.',
	5 => 'Authorization declined. Invalid amount. Please retry.',
	6 => 'Authorization declined. Expired credit card. Please retry with different credit card.',
	7 => 'Authorization declined. Invalid transaction. Please retry with different credit card.',
	8 => 'Received unexpected reply. Order not accepted. Please retry.',
	9 => 'Authorization declined. Duplicate transaction.',
	10 => 'Unknown issue. Order not accepted. Please retry.'
	};

    if ($transtype =~ /^(?:auth|sale)/) {
	# Interchange names are on the left, WellsFargo on the right
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

#::logDebug(qq{WellsFargo %result after result_map loop:\n} . ::uneval(\%result) );

	if (exists $wellsfargo_accept_map{ $result{ioc_response_code} } ) {
		$result{MStatus} = 'success';
		$result{'order-id'} ||= $opt->{order_id};
	}
	else {
		$result{MStatus} = 'failure';
		delete $result{'order-id'};

		my $msg = $opt->{message_declined} ||
				$result{ioc_reject_description} || 
				$response_map->{ $result{ioc_response_code} } ||
				$timeout_error;
		$msg .= '<p>Please contact customer service or try a different card.</p>';
		$result{MErrMsg} = errmsg($msg);
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

#::logDebug("WellsFargo sale query (before passed query params): " . ::uneval(\%query));

	if ( scalar keys %$extra ) {
             my @new_keys = keys %$extra;
             @query{ @new_keys } = @{ $extra }{ @new_keys };
	}

#::logDebug("WellsFargo sale query (after passed query params): " . ::uneval(\%query));

	my %sale_result = $call_gateway->($opt,\%query,1);

	foreach (keys %sale_result) {
		$result{$_} = $sale_result{$_}
			unless exists $result{$_};
	}

        $sale_result{ioc_response_code} =~ s/\s+//g;
	if ( $sale_result{ioc_response_code} != 0) {
		$result{MStatus} = 'failure';
		delete $result{'order-id'};

		my $msg = "<p>Authorization passed but settlment failed (gateway returned code %s: %s).</p><p>Please contact customer service or try a different card.</p>";
		$result{MErrMsg} = errmsg($msg, $sale_result{ioc_response_code},
						$sale_result{ioc_response_desc} ||
						$response_map->{ $sale_result{ioc_response_code} } ||
						'(unknown)');
	}
    }

    elsif ($transtype =~ /^(?:settle|return)/) {
	$result{ioc_response_code} =~ s/\s+//g;
	if ( $result{ioc_response_code} != 0) {
		$result{MStatus} = 'failure';
		my $msg = "transaction failed with code %s: %s";
		$result{MErrMsg} = errmsg($msg, $result{ioc_response_code},
						$result{ioc_response_desc} ||
						$response_map->{ $result{ioc_response_code} } ||
						'(unknown)');
	}
	else {
		$result{MStatus} = 'success';
	}
    }
    return (%result);
}

package Vend::Payment::WellsFargo;

1;
