#!/usr/bin/perl
#
# $Id: AuthorizeNet.pm,v 1.1.2.1 2001-04-09 17:35:56 heins Exp $
#
# Copyright (C) 1999-2001 Red Hat, Inc., http://www.redhat.com
#
# by mark@summersault.com with code reused and inspired by
#	Mike Heins <mike@minivend.com>
#	webmaster@nameastar.net
#   Jeff Nappi <brage@cyberhighway.net>
#   Paul Delys <paul@gi.alaska.edu>
#  Edited by Ray Desjardins <ray@dfwmicrotech.com>

# Patches for AUTH_CAPTURE and VOID support contributed by
# nferrari@ccsc.com (Nelson H Ferrari)

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
# Connection routine for AuthorizeNet version 3 using the 'ADC Direct Response'
# method.

# Reworked extensively to support new Interchange payment stuff by Mike Heins

package Vend::Payment::AuthorizeNet;

=head1 Interchange AuthorizeNet Support

Vend::Payment::AuthorizeNet $Revision: 1.1.2.1 $

=head1 SYNOPSIS

    &charge=authorizenet
 
        or
 
    [charge mode=authorizenet param1=value1 param2=value2]

=head1 PREREQUISITES

Net::SSLeay

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
Global parameter is MV_PAYMENT_SECRET.

=item referer

A valid referering url (match this with your setting on secure.authorize.net).
Global parameter is MV_PAYMENT_REFERER.

=item transaction

The type of transaction to be run. Valid values are:

    Interchange mode    AuthorizeNet mode
    ----------------    -----------------

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

Make sure Net::SSLeay is installed and working. You can test to see whether
your Perl thinks it is:

    perl -MNet::SSLeay -e 'print "It works\n"'

=item *

Check the error logs, both catalog and global.

=item *

Make sure you set your payment parameters properly.  

=item *

Try an order, then put this code in a page:

    [calc]
        $Tag->uneval( { ref => $Session->{payment_result} );
    [/calc]

That should show what happened.

=item *

If all else fails, Red Hat and other consultants are available to help
with integration for a fee.

=back

=head1 BUGS

There is actually nothing *in* Vend::Payment::AuthorizeNet. It changes packages
to Vend::Payment and places things there.

=head1 AUTHORS

Mark Stosberg <mark@summersault.com>, based on original code by Mike Heins
<mheins@redhat.com>.

=head1 CREDITS

    Jeff Nappi <brage@cyberhighway.net>
    Paul Delys <paul@gi.alaska.edu>
    webmaster@nameastar.net
    Ray Desjardins <ray@dfwmicrotech.com>
    Nelson H. Ferrari <nferrari@ccsc.com>

=cut

package Vend::Payment;

use Net::SSLeay qw(post_https make_form make_headers);

sub authorizenet {
	my ($user, $secret, $amount) = @_;

	my $opt;
	if(ref $user) {
		$opt = $user;
		$user = $opt->{id} || undef;
		$secret = $opt->{secret} || undef;
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
	
	if (! $user ) {
		$user    =  charge_param('id')
						or return (
							MStatus => 'failure-hard',
							MErrMsg => errmsg('No account id'),
							);
	}
	
	$secret  =  $opt->{secret} if ! $secret;
	if(! $secret) {
		$secret    =  charge_param('secret')
						or return (
							MStatus => 'failure-hard',
							MErrMsg => errmsg('No account id'),
							);
    }

    my $server  =   $opt->{server}
					|| 'secure.authorize.net';

    my $script 	=   $opt->{script}
					|| '/gateway/transact.dll';

    my $port    =   $opt->{port}
					|| 443;

	my $precision = $opt->{precision} 
                    || 2;

	my $referer   =  $opt->{referer}
					|| charge_param('referer');

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
		auth		 			=>	'ONLY',
		authorize		 		=>	'AUTH_ONLY',
		mauthcapture 			=>	'AUTH_CAPTURE',
		mauthonly				=>	'AUTH_ONLY',
		return					=>	'CREDIT',
		reverse           		=>	'PRIOR_AUTH_CAPTURE',
		sale		 			=>	'AUTH_CAPTURE',
		settle      			=>  'CAPTURE_ONLY',
		void					=>	'VOID',
	);
	
	if (defined $type_map{$transtype}) {
        $transtype = $type_map{$transtype};
    }

	$amount = $opt->{total_cost} if $opt->{total_cost};
	
    if(! $amount) {
        $amount = Vend::Interpolate::total_cost();
        $amount = Vend::Util::round_to_frac_digits($amount,$precision);
    }

	$order_id = gen_order_id($opt);

    my %query = (
                    x_Test_Request	=> $opt->{test} || charge_param('test'),
                    x_Card_Num		=> $actual->{mv_credit_card_number},
                    x_First_Name    => $actual->{b_fname},
                    x_Last_Name     => $actual->{b_lname},
                    x_Address       => $actual->{address},
                    x_City          => $actual->{b_city},
                    x_State         => $actual->{b_state},
                    x_Zip			=> $actual->{zip},
					x_Type			=> $actual->{cyber_mode},
                    x_Amount    	=> $amount,
                    x_Exp_Date  	=> $exp,
                    x_Method    	=> 'CC',
					x_Trans_ID		=> $actual->{order_id},
					x_Auth_Code		=> $actual->{auth_code},
                    x_Invoice_Num   => $actual->{mv_order_number},
#                    x_Company      => $actual->{company},
#                    x_Phone        => $actaul->{phone_day},
                    x_Password  	=> $secret,
                    x_Login     	=> $user,
                    x_Version   	=> '3.0',
                    x_ADC_URL   	=> 'FALSE',
                    x_ADC_Delim_Data	=> 'TRUE',

    );

    my @query;

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
    my $string = join '&', @query;

#::logDebug("Authorizenet query: " . ::uneval(\%query));
    my ($page, $response, %reply_headers)
                = post_https($server, $port, $script,
                	   make_headers( Referer => $referer),
                       make_form(
                               %query
                       ));
	
    # Minivend names are on the  left, Authorize.Net on the right
    my %result_map = ( qw/
            MStatus               x_response_code
            pop.status            x_response_code
            MErrMsg               x_response_reason_text
            pop.error-message     x_response_reason_text
            order-id              x_trans_id
            pop.order-id          x_trans_id
            pop.auth-code         x_auth_code
            pop.avs_code          x_avs_code
            pop.avs_zip           x_zip
            pop.avs_addr          x_address
    /
    );


#::logDebug(qq{\nauthorizenet page: $page response: $response\n});

    my ($response_code,
    	$response_subcode,
    	$response_reason_code,
    	$response_reason_text,
    	$auth_code,
    	$avs_code,
    	$trans_id) = split (/,/,$page);
    	
#::logDebug(qq{authorizenet response_reason_text=$response_reason_text response_code: $response_code});    	

    my %result;
    if ($response_code == 1) {
    	$result{MStatus} = 'success';
    	# order-id and auth_code are set to 0 if Authorize.net in test mode.
		# Order.pm interprets order-id == 0 as authorization error.
		$result{'order-id'} = $trans_id || 1;
		$result{'auth_code'} = $auth_code;
    }
	else {
    	$result{MStatus} = 'failure';

		# NOTE: A lot more AVS codes could be checked for here.
    	if ($avs_code eq 'N') {
			my $msg = $opt->{message_avs} ||
				q{You must enter the correct billing address of your credit card.  The bank returned the following error: %s};
			$result{MErrMsg} = errmsg($msg, $response_reason_text);
    	}
		else {
			my $msg = $opt->{message_declined} ||
				"Authorizenet error: %s. Please call in your order or try again.";
    		$result{MErrMsg} = errmsg($msg, $response_reason_text);
    	}
    }

    return (%result);
}

package Vend::Payment::AuthorizeNet;

1;
