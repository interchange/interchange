# Vend::Payment::EFSNet - Interchange EFSNet support
#
# $Id: EFSNet.pm,v 1.7 2009-03-16 19:34:00 jon Exp $
#
# Connection routine for Concord EFSNet ( http://www.concordefsnet.com/ )
#
# Based on AuthorizeNet.pm. Modified for EFSNet by Chris Wenham of Synesmedia, Inc.
# cwenham@synesmedia.com, http://www.synesmedia.com/
#
# Copyright (C) 2005-2007 Interchange Development Group,
# http://www.icdevgroup.org/
# Copyright (C) 1999-2002 Red Hat, Inc.
#
# Authors:
# cwenham@synesmedia.com
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

package Vend::Payment::EFSNet;

=head1 NAME

Vend::Payment::EFSNet - Interchange EFSNet Support

=head1 SYNOPSIS

    &charge=efsnet
 
        or
 
    [charge mode=efsnet param1=value1 param2=value2]

=head1 PREREQUISITES

  Net::SSLeay
 
    or
  
  LWP::UserAgent and Crypt::SSLeay

Only one of these need be present and working.

=head1 DESCRIPTION

The Vend::Payment::EFSNet module implements the efsnet() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::EFSNet

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<efsnet>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  efsnet

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge mode=efsnet id=YourEFSNetID]

or

    Route efsnet id YourEFSNetID

or 

    Variable MV_PAYMENT_ID      YourEFSNetID

The active settings are:

=over 4

=item id

Your EFSNet Store ID, which you can get from the Merchant Services 
panel after logging in with the username and password supplied to you
by Concord when you signed up.

http://www.concordefsnet.com/Developers/MerchantLogin.asp

(Check the "Credentials" page after login)

Global parameter is MV_PAYMENT_ID.

=item secret

Your EFSNet Store Key, which you can get from the Merchant Services
panel.
Global parameter is MV_PAYMENT_SECRET. 

=item transaction

The type of transaction to be run. Valid values are:

    Interchange         EFSNet
    ----------------    -----------------
        auth            CreditCardAuthorize
        return          CreditCardRefund
        reverse         CreditCardRefund
        sale            CreditCardCharge
        settle          CreditCardSettle
        void            VoidTransaction

=item remap 

This remaps the form variable names to the ones needed by EFSNet. See
the C<Payment Settings> heading in the Interchange documentation for use.

=back

=head2 Troubleshooting

Try the instructions above, then switch to the test servers. A test order 
should complete with this test card number: 4111 1111 1111 1111

Enabling the test servers:

MV_PAYMENT_HOST testefsnet.concordebiz.com



If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::EFSNet

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

=head1 NOTES

CreditCardCredit transactions (where you apply a credit on a card without the
transaction ID of a previous charge) are supported by this module, but disabled 
by default in new EFSNet accounts. If you need to use this function, call EFSNet.

This module supports partial returns, but EFSNet needs to know what the original 
transaction amount was. You can provide this by passing the value in the
original_amount parameter.

=head1 CHANGES

Concord EFSNet requires all interface code to be certified by them. If 
you make a change to this module, please contact EFSNet for re-certification.
More information at: http://www.concordefsnet.com/Developers/Documentation.asp

=head1 BUGS

There is actually nothing *in* Vend::Payment::EFSNet. It changes packages
to Vend::Payment and places things there.

=head1 AUTHORS

Chris Wenham <cwenham@synesmedia.com>.
Based on code by Mark Stosberg <mark@summersault.com>
and Mike Heins <mike@perusion.com>.

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

sub efsnet {
	my ($user, $amount) = @_;
	
	my $version = "Interchange EFSNet Module v1.1.0";
	
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

    $opt->{host}   ||= 'efsnet.concordebiz.com';

    $opt->{script} ||= '/efsnet.dll';

    $opt->{port}   ||= 443;
    
#::logDebug("Host: $opt->{host} Script: $opt->{script}");

	my $precision = $opt->{precision} 
                    || 2;

	my @override = qw/
						order_id
						auth_code
						amount
						mv_credit_card_exp_month
						mv_credit_card_exp_year
						mv_credit_card_number
					/;
	for(@override) {
		next unless defined $opt->{$_};
		$actual->{$_} = $opt->{$_};
	}

	# Make sure exp. month is 2 digits, padded with zeros
	$actual->{mv_credit_card_exp_month} = sprintf('%02d', $actual->{mv_credit_card_exp_month});
	
	$actual->{mv_credit_card_number} =~ s/\D//g;

	# Using mv_payment_mode for compatibility with older versions, probably not
	# necessary.
	$opt->{transaction} ||= 'sale';
	my $transtype = $opt->{transaction};

	my %type_map = (
		AUTH_ONLY			=>	'CreditCardAuthorize',
		CAPTURE_ONLY			=>	'CreditCardCapture',
		CREDIT				=>	'CreditCardCredit',
		PRIOR_AUTH_CAPTURE		=>	'CreditCardSettle',
		VOID				=>	'VoidTransaction',
		auth				=>	'CreditCardAuthorize',
		authorize			=>	'CreditCardAuthorize',
		mauthcapture			=>	'CreditCardCharge',
		mauthonly			=>	'CreditCardAuthorize',
		return				=>	'CreditCardRefund',
		settle_prior			=>	'CreditCardSettle',
		sale				=>	'CreditCardCharge',
		settle  			=>	'CreditCardSettle',
		void				=>	'VoidTransaction',
	);

	if (defined $type_map{$transtype}) {
        	$transtype = $type_map{$transtype};
	}

	$amount = $opt->{total_cost} if $opt->{total_cost};
	
    if(! $amount) {
        $amount = Vend::Interpolate::total_cost();
        $amount = Vend::Util::round_to_frac_digits($amount,$precision);
    }

    %order_id_check = (
	efsnet => sub {
					my $val = shift;
					# Cannot be longer than 12 characters
					$val = substr($val, -12);
					return $val;
				},
	);
    
	my $order_id = gen_order_id($opt);
	
#::logDebug("auth_code=$actual->{auth_code} order_id=$opt->{order_id}");
    my %query = (
    		Method				=> $transtype,
		StoreKey			=> $secret,
		StoreID				=> $user,
    		ApplicationID			=> $version,
		BillingName			=> "$actual->{b_fname} $actual->{b_lname}",
		BillingAddress			=> $actual->{b_address},
		BillingCity			=> $actual->{b_city},
		BillingState			=> $actual->{b_state},
		BillingZip			=> $actual->{b_zip},
		BillingCountry			=> $actual->{b_country},
		BillingEmail			=> $actual->{email},
		BillingPhone			=> $actual->{phone_day},
		ShippingName			=> "$actual->{fname} $actual->{lname}",
		ShippingAddress			=> $actual->{address},
		ShippingCity			=> $actual->{city},
		ShippingState			=> $actual->{state},
		ShippingZip			=> $actual->{zip},
		ShippingCountry			=> $actual->{country},
		TransactionAmount		=> $amount,
		AccountNumber			=> $actual->{mv_credit_card_number},
		ExpirationMonth			=> $actual->{mv_credit_card_exp_month},
		ExpirationYear			=> $actual->{mv_credit_card_exp_year},
		CardVerificationValue		=> $actual->{cvv2},
		ReferenceNumber			=> $order_id,
    );

    if ($transtype =~ /(CreditCardSettle|CreditCardRefund)/) {
    	$query{OriginalTransactionID} = $actual->{auth_code};
	$query{OriginalTransactionAmount} = $opt->{original_amount} || $amount;
    }
    
    if ($transtype eq 'VoidTransaction') {
    	$query{TransactionID} = $actual->{auth_code};
    }
    
    if ($transtype eq 'CreditCardCapture') {
    	$query{AuthorizationNumber} = $actual->{auth_code};
    }
    
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

#::logDebug("EFSNet query: " . ::uneval(\%query));

    my $thing    = post_data($opt, \%query);
    my $page     = $thing->{result_page};
    my $response = $thing->{status_line};
	
    # Interchange names are on the  left, EFSNet on the right
    my %result_map = ( qw/
            pop.status            ResponseCode
            pop.error-message     ResultMessage
            order-id              TransactionID
            pop.order-id          TransactionID
            pop.auth-code         ApprovalNumber
            pop.avs_code          AVSResponseCode
            pop.cvv2_resp_code    CVVResponseCode
    /
    );


#::logDebug(qq{\nefsnet page: $page response: $response\n});

   my %result;
   my @results = split /\&/,$page;
   foreach (@results) {
   	my ($key,$val) = split '=', $_;
	$result{$key} = $val;
   }
    	
#::logDebug(qq{efsnet response_reason_text=$result{ResultMessage} response_code: $result{ResponseCode}});    	

    for (keys %result_map) {
        $result{$_} = $result{$result_map{$_}}
            if defined $result{$result_map{$_}};
    }

    if ($result{ResponseCode} == 0) {
    	$result{MStatus} = 'success';
		$result{'order-id'} ||= $opt->{order_id};
    }
	else {
    	$result{MStatus} = 'failure';
		delete $result{'order-id'};

		# NOTE: A lot more AVS codes could be checked for here.
    	if ($result{AVSResponseCode} eq 'N') {
			my $msg = $opt->{message_avs} ||
				q{You must enter the correct billing address of your credit card.  The bank returned the following error: %s};
			$result{MErrMsg} = errmsg($msg, $result{ResultMessage});
    	}
		else {
			my $msg = $opt->{message_declined} ||
				"EFSNet error: %s. Please call in your order or try again.";
    		$result{MErrMsg} = errmsg($msg, $result{ResultMessage});
    	}
    }
#::logDebug(qq{efsnet result=} . uneval(\%result));    	

    return (%result);
}

package Vend::Payment::EFSNet;

1;
