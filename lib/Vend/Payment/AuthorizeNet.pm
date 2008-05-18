# Vend::Payment::AuthorizeNet - Interchange AuthorizeNet support
#
# Connection routine for AuthorizeNet version 3 using the 'ADC Direct Response'
# method.
#
# $Id: AuthorizeNet.pm,v 2.19 2007-11-15 00:16:16 jon Exp $
#
# Copyright (C) 2003-2007 Interchange Development Group, http://www.icdevgroup.org/
# Copyright (C) 1999-2002 Red Hat, Inc.
#
# Authors:
# mark@summersault.com
# Mike Heins <mike@perusion.com>
# Jeff Nappi <brage@cyberhighway.net>
# Paul Delys <paul@gi.alaska.edu>
# webmaster@nameastar.net
# Ray Desjardins <ray@dfwmicrotech.com>
# Nelson H Ferrari <nferrari@ccsc.com>

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

package Vend::Payment::AuthorizeNet;

=head1 NAME

Vend::Payment::AuthorizeNet - Interchange AuthorizeNet Support

=head1 SYNOPSIS

    &charge=authorizenet
 
        or
 
    [charge mode=authorizenet param1=value1 param2=value2]

=head1 PREREQUISITES

  Net::SSLeay
 
    or
  
  LWP::UserAgent and Crypt::SSLeay

Only one of these need be present and working.

=head1 DESCRIPTION

The Vend::Payment::AuthorizeNet module implements the authorizenet() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules -- in theory (and even usually in practice) you
could switch from CyberCash to Authorize.net with a few configuration 
file changes.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::AuthorizeNet

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<authorizenet>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  authorizenet

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge mode=authorizenet id=YourAuthorizeNetID]

or

    Route authorizenet id YourAuthorizeNetID

or 

    Variable MV_PAYMENT_ID      YourAuthorizeNetID

The active settings are:

=over 4

=item id

Your Authorize.net account ID, supplied by Authorize.net when you sign up.
Global parameter is MV_PAYMENT_ID.

=item secret

Your Authorize.net account password, supplied by Authorize.net when you sign up.
Global parameter is MV_PAYMENT_SECRET. This may not be needed for
actual charges.

=item referer

A valid referering url (match this with your setting on secure.authorize.net).
Global parameter is MV_PAYMENT_REFERER.

=item transaction

The type of transaction to be run. Valid values are:

    Interchange         AuthorizeNet
    ----------------    -----------------
        auth            AUTH_ONLY
        return          CREDIT
        reverse         PRIOR_AUTH_CAPTURE
        sale            AUTH_CAPTURE
        settle          CAPTURE_ONLY
        void            VOID

=item remap 

This remaps the form variable names to the ones needed by Authorize.net. See
the C<Payment Settings> heading in the Interchange documentation for use.

=item test

Set this to C<TRUE> if you wish to operate in test mode, i.e. set the Authorize.net
C<x_Test_Request> query paramter to TRUE.i

Examples: 

    Route    authorizenet  test  TRUE
        or
    Variable   MV_PAYMENT_TEST   TRUE
        or 
    [charge mode=authorizenet test=TRUE]

=back

=head2 Troubleshooting

Try the instructions above, then enable test mode. A test order should complete.

Disable test mode, then test in various Authorize.net error modes by
using the credit card number 4222 2222 2222 2222.

Then try a sale with the card number C<4111 1111 1111 1111>
and a valid expiration date. The sale should be denied, and the reason should
be in [data session payment_error].

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::AuthorizeNet

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
See http://www.icdevgroup.org/ for mailing lists and other information.

=back

=head1 BUGS

There is actually nothing *in* Vend::Payment::AuthorizeNet. It changes packages
to Vend::Payment and places things there.

=head1 AUTHORS

Mark Stosberg <mark@summersault.com>.
Based on original code by Mike Heins <mike@perusion.com>.

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
use strict;

sub authorizenet {
	my ($user, $amount) = @_;

	my $opt;
	my $secret;
	
	if(ref $user) {
		$opt = $user;
		$user = $opt->{id} || undef;
		$secret = $opt->{secret} || undef;
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
	
	$secret    =  charge_param('secret') if ! $secret;

    $opt->{host}   ||= 'secure.authorize.net';

    $opt->{script} ||= '/gateway/transact.dll';

    $opt->{port}   ||= 443;

	$opt->{method} ||= charge_param('method') || 'CC';

	my $precision = $opt->{precision} 
                    || 2;

	my $referer   =  $opt->{referer}
					|| charge_param('referer');

	my @override = qw/
						order_id
						auth_code
						mv_credit_card_exp_month
						mv_credit_card_exp_year
						mv_credit_card_number
					/;
	for(@override) {
		next unless defined $opt->{$_};
		$actual->{$_} = $opt->{$_};
	}

	## Authorizenet does things a bit different, ensure we are OK
	$actual->{mv_credit_card_exp_month} =~ s/\D//g;
    $actual->{mv_credit_card_exp_month} =~ s/^0+//;
    $actual->{mv_credit_card_exp_year} =~ s/\D//g;
    $actual->{mv_credit_card_exp_year} =~ s/\d\d(\d\d)/$1/;

    $actual->{mv_credit_card_number} =~ s/\D//g;

    my $exp = sprintf '%02d%02d',
                        $actual->{mv_credit_card_exp_month},
                        $actual->{mv_credit_card_exp_year};

	# Using mv_payment_mode for compatibility with older versions, probably not
	# necessary.
	$opt->{transaction} ||= 'sale';
	my $transtype = $opt->{transaction};

	my %type_map = (
		AUTH_ONLY				=>	'AUTH_ONLY',
		CAPTURE_ONLY			=>  'CAPTURE_ONLY',
		CREDIT					=>	'CREDIT',
		PRIOR_AUTH_CAPTURE		=>	'PRIOR_AUTH_CAPTURE',
		VOID					=>	'VOID',
		auth		 			=>	'AUTH_ONLY',
		authorize		 		=>	'AUTH_ONLY',
		mauthcapture 			=>	'AUTH_CAPTURE',
		mauthonly				=>	'AUTH_ONLY',
		return					=>	'CREDIT',
		settle_prior        	=>	'PRIOR_AUTH_CAPTURE',
		sale		 			=>	'AUTH_CAPTURE',
		settle      			=>  'CAPTURE_ONLY',
		void					=>	'VOID',
	);

	if (defined $type_map{$transtype}) {
        $transtype = $type_map{$transtype};
    }

	my %allowed_map = (
		CC => {
					AUTH_CAPTURE => 1,
					AUTH_ONLY => 1,
					CAPTURE_ONLY => 1,
					CREDIT => 1,
					VOID => 1,
					PRIOR_AUTH_CAPTURE => 1,
				},
	    ECHECK => {
					AUTH_CAPTURE => 1,
					CREDIT => 1,
					VOID => 1,
				},
	);

	if(! $allowed_map{$opt->{method}}) {
		::logDebug("Unknown Authorizenet method $opt->{method}");
	}
	elsif(! $allowed_map{$opt->{method}}{$transtype}) {
		::logDebug("Unknown Authorizenet transtype $transtype for $opt->{method}");
	}

	$amount = $opt->{total_cost} if $opt->{total_cost};
	
    if(! $amount) {
        $amount = Vend::Interpolate::total_cost();
        $amount = Vend::Util::round_to_frac_digits($amount,$precision);
    }

	my $order_id = gen_order_id($opt);

#::logDebug("auth_code=$actual->{auth_code} order_id=$opt->{order_id}");
	my %echeck_params = (
		x_bank_aba_code    => $actual->{check_routing},
		x_bank_acct_num    => $actual->{check_account},
		x_bank_acct_type   => $actual->{check_accttype},
		x_bank_name        => $actual->{check_bankname},
		x_bank_acct_name   => $actual->{check_acctname},
		x_Method => 'ECHECK',
	);

    my %query = (
		x_Test_Request			=> $opt->{test} || charge_param('test'),
		x_First_Name			=> $actual->{b_fname},
		x_Last_Name				=> $actual->{b_lname},
		x_Company				=> $actual->{b_company},
		x_Address				=> $actual->{b_address},
		x_City					=> $actual->{b_city},
		x_State					=> $actual->{b_state},
		x_Zip					=> $actual->{b_zip},
		x_Country				=> $actual->{b_country},
		x_Ship_To_First_Name	=> $actual->{fname},
		x_Ship_To_Last_Name		=> $actual->{lname},
		x_Ship_To_Company		=> $actual->{company},
		x_Ship_To_Address		=> $actual->{address},
		x_Ship_To_City			=> $actual->{city},
		x_Ship_To_State			=> $actual->{state},
		x_Ship_To_Zip			=> $actual->{zip},
		x_Ship_To_Country		=> $actual->{country},
		x_Email					=> $actual->{email},
		x_Phone					=> $actual->{phone_day},
		x_Type					=> $transtype,
		x_Amount				=> $amount,
		x_Method				=> 'CC',
		x_Card_Num				=> $actual->{mv_credit_card_number},
		x_Exp_Date				=> $exp,
		x_Card_Code				=> $actual->{cvv2} || $actual->{mv_credit_card_cvv2},
		x_Customer_IP			=> $Vend::Session->{ohost},
		x_Trans_ID				=> $actual->{order_id},
		x_Auth_Code				=> $actual->{auth_code},
		x_Invoice_Num			=> $actual->{mv_order_number},
		x_Password				=> $secret,
		x_Login					=> $user,
		x_Version				=> '3.1',
		x_ADC_URL				=> 'FALSE',
		x_ADC_Delim_Data		=> 'TRUE',
		x_ADC_Delim_Character	=> "\037",
    );

    my @query;

	my @only_cc = qw/ x_Card_Num x_Exp_Date x_Card_Code /;

	if($opt->{use_transaction_key}) {
		$query{x_Tran_Key} = delete $query{x_Password};
	}

	if($opt->{method} eq 'ECHECK') {
		for (@only_cc) {
			delete $query{$_};
		}
		for(keys %echeck_params) {
			$query{$_} = $echeck_params{$_};
		}
	}

    for (keys %query) {
        my $key = $_;
        my $val = $query{$key};
        $val =~ s/["\$\n\r]//g;
        $val =~ s/\$//g;
        my $len = length($val);
        if($val =~ /[&=]/) {
            $key .= "[$len]";
        }
        push @query, "$key=$val";
    }

#::logDebug("Authorizenet query: " . ::uneval(\%query));
    $opt->{extra_headers} = { Referer => $referer };

    my $thing    = post_data($opt, \%query);
    my $page     = $thing->{result_page};
    my $response = $thing->{status_line};
	
    # Minivend names are on the  left, Authorize.Net on the right
    my %result_map = ( qw/
            pop.status            x_response_code
            pop.error-message     x_response_reason_text
            order-id              x_trans_id
            pop.order-id          x_trans_id
            pop.auth-code         x_auth_code
            pop.avs_code          x_avs_code
            pop.avs_zip           x_zip
            pop.avs_addr          x_address
            pop.cvv2_resp_code    x_cvv2_resp_code
    /
    );


#::logDebug(qq{\nauthorizenet page: $page response: $response\n});

    my %result;
    @result{
		qw/
			x_response_code
			x_response_subcode
			x_response_reason_code
			x_response_reason_text
			x_auth_code
			x_avs_code
			x_trans_id
			x_invoice_num
			x_description
			x_amount
			x_method
			x_type
			x_cust_id
			x_first_name
			x_last_name
			x_company
			x_address
			x_city
			x_state
			x_zip
			x_country
			x_phone
			x_fax
			x_email
			x_ship_to_first_name
			x_ship_to_last_name
			x_ship_to_company
			x_ship_to_address
			x_ship_to_city
			x_ship_to_state
			x_ship_to_zip
			x_ship_to_country
			x_tax
			x_duty
			x_freight
			x_tax_exempt
			x_po_num
			x_MD5_hash
			x_cvv2_resp_code			
		/
		}
		 = split (/\037/,$page);
    	
#::logDebug(qq{authorizenet response_reason_text=$result{x_response_reason_text} response_code: $result{x_response_code}});    	

    for (keys %result_map) {
        $result{$_} = $result{$result_map{$_}}
            if defined $result{$result_map{$_}};
    }

    if ($result{x_response_code} == 1) {
    	$result{MStatus} = 'success';
		$result{'order-id'} ||= $opt->{order_id};
    }
	else {
    	$result{MStatus} = 'failure';
		delete $result{'order-id'};

		# NOTE: A lot more AVS codes could be checked for here.
    	if ($result{x_avs_code} eq 'N') {
			my $msg = $opt->{message_avs} ||
				q{You must enter the correct billing address of your credit card.  The bank returned the following error: %s};
			$result{MErrMsg} = errmsg($msg, $result{x_response_reason_text});
    	}
		else {
			my $msg = $opt->{message_declined} ||
				"Authorizenet error: %s. Please call in your order or try again.";
    		$result{MErrMsg} = errmsg($msg, $result{x_response_reason_text});
    	}
    }
#::logDebug(qq{authorizenet result=} . uneval(\%result));    	

    return (%result);
}

package Vend::Payment::AuthorizeNet;

1;
