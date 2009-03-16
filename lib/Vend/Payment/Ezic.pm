# Vend::Payment::Ezic - Interchange Ezic support
#
# $Id: Ezic.pm,v 1.6 2009-03-16 19:34:00 jon Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1999-2002 Red Hat, Inc. <interchange@redhat.com>
#
# by shawn@oceanebi.com with code reused and inspired by
#    mark@summersault.com 
#	Mike Heins <mheins@redhat.com>
#	webmaster@nameastar.net
#   Jeff Nappi <brage@cyberhighway.net>
#   Paul Delys <paul@gi.alaska.edu>
#  Edited by Ray Desjardins <ray@dfwmicrotech.com>
#  
#  Reworked for EziC "Native Direct Mode v.3 (SAS) Channel" support by
#  	Mark Lipscombe <markl@gasupnow.com>
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
# Connection routine for Ezic version 3 using the 'ADC Direct Response'
# method.
# Reworked extensively to support new Interchange payment stuff by Mike Heins
package Vend::Payment::Ezic;
=head1 Interchange Ezic Support

Vend::Payment::Ezic $Revision: 1.6 $

=head1 SYNOPSIS

    &charge=ezic
 
        or
 
    [charge mode=ezic param1=value1 param2=value2]

=head1 PREREQUISITES

  Net::SSLeay
 
    or
  
  LWP::UserAgent and Crypt::SSLeay

Only one of these need be present and working.

=head1 DESCRIPTION

The Vend::Payment::Ezic module implements the ezic() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::Ezic

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<ezic>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  ezic

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge mode=ezic id=YourEzicID]

or

    Route ezic id YourEzicID

or 

    Variable MV_PAYMENT_ID      YourEzicID

The active settings are:

=over 4

=item id

Your 12-digit EziC account number, supplied by EziC when you sign up.
Global parameter is MV_PAYMENT_ID.

=item site_id

A valid "site id", as configured in the EziC control panel.  This controls
which templates are used for email receipts.  Global parameter is MV_PAYMENT_REFERER.

=item transaction

The type of transaction to be run. Valid values are:

    Interchange         Ezic
    ----------------    -----------------
        auth            A (Auth)
        return          C (Credit)
        reverse         R (Refund)
        sale            S (Sale)
        settle          D (Capture)
        void            R (Refund)

=item remap 

This remaps the form variable names to the ones needed by EziC. See
the C<Payment Settings> heading in the Interchange documentation for use.

=back

=head2 Troubleshooting

Try the instructions above, then enable test mode in the EziC control panel.
A test order should complete.

Disable test mode, then test in various Authorize.net error modes by
using the credit card number configured in the "setup" section of the EziC
control panel.  In the Documentation section of that control panel, an
up to date list of amounts that generate different error responses is
provided.  Errors should appear in [data session payment_error].

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::Ezic

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

If all else fails, Red Hat and other consultants are available to help
with integration for a fee.

=back

=head1 BUGS

There is actually nothing *in* Vend::Payment::Ezic. It changes packages
to Vend::Payment and places things there.

=head1 AUTHORS

Mark Lipscombe <markl@gasupnow.com> and Mark Stosberg <mark@summersault.com>, based on original code by Mike Heins <mheins@redhat.com>.

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
		require URI::Escape;
		import URI::Escape qw(uri_unescape);
	};
	my $uri_escape;
	$uri_escape = 1 unless $@;
	unless ($uri_escape == 1) {
		die __PACKAGE__ . " requires URI::Escape";
	}

	eval {
		package Vend::Payment;
		require Net::SSLeay;
		import Net::SSLeay qw(post_https make_form make_headers);
		$selected = 'Net::SSLeay';
	};

	$Vend::Payment::Have_Net_SSLeay = 1 unless $@;

	unless ($Vend::Payment::Have_Net_SSLeay) {

		eval {
			package Vend::Payment;
			require LWP::UserAgent;
			require HTTP::Request::Common;
			require Crypt::SSLeay;
			import HTTP::Request::Common qw(POST);
			$selected = 'LWP and Crypt::SSLeay';
		};

		$Vend::Payment::Have_LWP = 1 unless $@;

	}

	unless ($Vend::Payment::Have_Net_SSLeay or $Vend::Payment::Have_LWP) {
		die __PACKAGE__ . ' requires Net::SSLeay or Crypt::SSLeay';
	}

	unless ($Vend::Payment::Have_Digest_MD5) {
		eval {
			package Vend::Payment;
			require Digest::MD5;
		};

		$Vend::Payment::Have_Digest_MD5 = 1 unless $@;
	}

	unless ($Vend::Payment::Have_Digest_MD5) {
		die __PACKAGE__ . ' requires Digest::MD5';
	}

	::logGlobal("%s payment module initialized, using %s", __PACKAGE__, $selected)
		unless $Vend::Quiet;

}

package Vend::Payment;
sub ezic {
	my ($user, $amount) = @_;

	my $opt;
	if(ref $user) {
		$opt = $user;
		$account_id = $opt->{account_id} || undef;
		$site_id    = $opt->{site_id} || undef;
		$site_tag   = $opt->{site_tag} || undef;
		$hash       = $opt->{hash} || undef;
	}
	else {
		$opt = {};
	}
	my $remote_host = $Vend::Session->{ohost};
	my $actual;
	if($opt->{actual}) {
		$actual = $opt->{actual};
	}
	else {
		my (%actual) = map_actual();
		$actual = \%actual;
	}

#::logDebug("actual map result: " . ::uneval($actual));

# Try and Get Cart Contents
	my $cartdesc = "";
	my $cart = $Vend::Session->{carts}->{main};
	foreach my $cartitems (@$cart) {
		$cartdesc .= sprintf(qq{ sku = %s, qty = %s, fmt = %s\n},
				$cartitems->{'code'},
				$cartitems->{'quantity'},
				$cartitems->{'formats'});	
	}


	if (! $user ) {
		$user    =  charge_param('id')
						or return (
							MStatus => 'failure-hard',
							MErrMsg => errmsg('No account id'),
							);
	}
	
	$secret    =  charge_param('secret') if ! $secret;

    $opt->{host}   ||= 'secure.ezic.com';

    $opt->{script} ||= '/gw/sas/direct3.0';

    $opt->{port}   ||= 1402;

	my $precision = $opt->{precision} 
                    || 2;

	my $referer   =  $opt->{referer}
					|| charge_param('referer');

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
	$opt->{transaction} ||= 'auth';
	my $transtype = $opt->{transaction};
	my $master_id = $opt->{master_id};
	my %type_map = (
		AUTH_ONLY			=>	'A',
		CAPTURE_ONLY			=>	'D',
		CREDIT				=>	'C',
		PRIOR_AUTH_CAPTURE		=>	'D',
		VOID				=>	'R',
		auth		 		=>	'A',
		authorize		 	=>	'A',
		mauthcapture 			=>	'S',
		mauthonly			=>	'A',
		return				=>	'C',
		reverse           		=>	'R',
		sale		 		=>	'S',
		settle      			=>	'D',
		void				=>	'R',
	);
	
	if (defined $type_map{$transtype}) {
        $transtype = $type_map{$transtype};
    }

	$amount = $opt->{total_cost} if $opt->{total_cost};
	
    if(! $amount) {
        $amount = Vend::Interpolate::total_cost();
        $amount = Vend::Util::round_to_frac_digits($amount,$precision);
    }

    my %query = ();
    if ($transaction !~ m/(R|C)/i) {
	 $order_id = gen_order_id($opt);

    	 %query = (
	 		account_id	=> $account_id,
			site_tag	=> $site_tag,
			pay_type	=> 'C',
			tran_type	=> $transtype,
			amount		=> $amount,
			bill_name1	=> $actual->{b_fname},
			bill_name2	=> $actual->{b_lname},
			bill_street	=> $actual->{b_address},
			bill_city	=> $actual->{b_city},
			bill_state	=> $actual->{b_state},
			bill_zip	=> $actual->{b_zip},
			bill_country	=> $actual->{b_country},
			cust_ip		=> $remote_host,
			cust_email	=> $actual->{email},
			cust_phone	=> $actual->{phone_day},
			description	=> $order_id,
			card_number	=> $actual->{mv_credit_card_number},
			card_expire	=> $exp
    	);
     } else {
	$order_id = $opt->{'order_id'};
	%query = (
		account_id	=> $account_id,
		tran_type	=> $transtype,
		orig_id		=> $master_id
	);
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

#::logDebug("EziC query: " . ::uneval(\%query));
    $opt->{extra_headers} = { Referer => $referer };

    my $thing    = post_data($opt, \%query);
    my $page     = $thing->{result_page};
    my $response = $thing->{status_line};
#::logDebug("EziC post_data response: " . ::uneval($thing) );

    # Minivend names are on the  left, Authorize.Net on the right
    my %result_map = ( qw/
            pop.status            status_code
            pop.error-message     auth_msg
            order-id              trans_id
            pop.order-id          trans_id
            pop.auth-code         auth_code
            pop.avs_code          avs_code
	    pop.cvv2_code	  cvv2_code
    /
    );

#::logDebug(qq{\nezic page: $page \n\nresponse: $response\n});
#::logGlobal(qq{\nezic page: $page \n\nresponse: $response\n});

    my %result= ();
    my @tmprslt = split('\&',$page);
    foreach my $rslt (@tmprslt) {
       my ($key,$val) = split('\=',$rslt);
       $result{$key} = uri_unescape($val);
    }

     #$result{dStatus} = $ezic_rsp->param("dStatus");
     #$result{dAuthMessage} = $ezic_rsp->param("dAuthMessage");
     #$result{dTransID} = $ezic_rsp->param("dTransID");
     #$result{dAuthCode} = $ezic_rsp->param("dAuthCode");
     #$result{dAVSCode} = $ezic_rsp->param("dAVSCode");
     #$result{dAVSMessage} = $ezic_rsp->param("dAVSMessage");
     #$result{dCVV2Code} = $ezic_rsp->param("dCVV2Code");
     #$result{dCVV2Message} = $ezic_rsp->param("dCVV2Message");

    for (keys %result_map) {
        $result{$_} = $result{$result_map{$_}}
            if defined $result{$result_map{$_}};
    }

    if ($result{'pop.status'} !~ m/(0|F)/) {
    	$result{MStatus} = 'success';
    } else {
    	$result{MStatus} = 'failure';
	$result{'order-id'} = '';

	
	# NOTE: A lot more AVS codes could be checked for here.
    	if ($result{'pop.avs_code'} eq 'N') {
			my $msg = $opt->{message_avs} ||
				qq{You must enter the correct billing address of your credit card.  The bank returned the following error: %s};
			$result{MErrMsg} = errmsg($msg, $result{'pop.error-message'});
    	} 

	if ($result{'pop.cvv2_code'} eq 'N') {
		my $msg = $opt->{message_cvv2} || 
				qq{Your CVV2 Code was not correct: %s};
				$result{MErrMsg} = $result{MErrMsg}.errmsg($msg,$result{'pop.error-message'});
	}
	my $msg = $opt->{message_declined} ||
		"Ezic error: %s. Please call in your order or try again.";
    	$result{MErrMsg} = errmsg($msg, $result{'pop.error-message'});
    }

    return (%result);
}

package Vend::Payment::Ezic;

1;

