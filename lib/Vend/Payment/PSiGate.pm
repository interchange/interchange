# Vend::Payment::PSiGate - Interchange PSiGate support
#
# $Id: PSiGate.pm,v 1.7 2007-08-09 13:40:55 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group <interchange@icdevgroup.org>
# Copyright (C) 1999-2002 Red Hat, Inc. <interchange@redhat.com>
#
#	Gary Benson <gary@geton.com>
#	Mike Heins <mikeh@perusion.com>
#	webmaster@nameastar.net
#   Jeff Nappi <brage@cyberhighway.net>
#   Paul Delys <paul@gi.alaska.edu>
#   Mark Stosberg <mark@summersault.com>
#
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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

# Connection routine for PSiGate using the 'HTML Posting Direct Response'
# method.

# Reworked extensively to support new Interchange payment stuff by Mike Heins

package Vend::Payment::PSiGate;

=head1 NAME

Vend::Payment::PSiGate - Interchange PSiGate Support

=head1 SYNOPSIS

    &charge=psigate

        or

    [charge mode=psigate param1=value1 param2=value2]

=head1 PREREQUISITES

  Net::SSLeay

    or

  LWP::UserAgent and Crypt::SSLeay

Only one of these need be present and working.

=head1 DESCRIPTION

The Vend::Payment::PSiGate module implements the psigate() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules -- in theory (and even usually in practice) you
could switch from CyberCash to PSiGate.com with a few configuration
file changes.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::PSiGate

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<psigate>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  psigate

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call 
options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge mode=psigate id=YourPSiGateMerchantID]

or

    Route psigate id YourPSiGateMerchantID

or

    Variable MV_PAYMENT_ID      YourPSiGateMerchantID

The active settings are:

=over 4

=item id

Your PSiGate.com account ID, supplied by PSiGate.com when you sign up.
Global parameter is MV_PAYMENT_ID.

=item referer

A valid referering url (match this with your setting on PSiGate).
Global parameter is MV_PAYMENT_REFERER.

=item transaction

The type of transaction to be run. Valid values are:

    Interchange         PSiGate               Note
    ----------------    -----------------     ---------
        auth            '1',                  PreAuth
        sale            '0',                  Sale
        settle          '2',                  PostAuth
        void            '9',                  Void

=item remap

This remaps the form variable names to the ones needed by PSiGate. See
the C<Payment Settings> heading in the Interchange documentation for use.

=item test

Set this to C<TRUE> if you wish to operate in test mode, i.e. set the 
PSiGate
C<x_Test_Request> query paramter to TRUE.i

Examples:

    Route    psigate  test  TRUE
        or
    Variable   MV_PAYMENT_TEST   TRUE
        or
    [charge mode=psigate test=TRUE]

=back

=head2 Troubleshooting

Try the instructions above, then enable test mode. A test order should 
complete.

Disable test mode, then test in various PSiGate error modes by
using the credit card number 4111 1111 1111 1111.

Then try a sale with the card number C<4111 1111 1111 1111>
and a valid expiration date. The sale should be denied, and the reason 
should
be in [data session payment_error].

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::PSiGate

=item *

Make sure either Net::SSLeay or Crypt::SSLeay and LWP::UserAgent are 
installed
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

There is actually nothing *in* Vend::Payment::PSiGate. It changes packages
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
sub psigate {
	my ($user, $amount) = @_;

	my $opt;
	if(ref $user) {
		$opt = $user;
		$user = $opt->{id} || undef;
#		$secret = $opt->{secret} || undef;
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
		$user    =  charge_param('id');
		if (! $user ) {
			return (
					MStatus => 'failure-hard',
					MErrMsg => errmsg('No account id'),
					);
		}
	}

#	$secret    =  charge_param('secret') if ! $secret;

    $opt->{host}   ||= 'order.psigate.com';

    $opt->{script} ||= 'order.asp';

    $opt->{port}   ||= 443;

    my $precision = $opt->{precision}
                   || 2;

#    my $referer   =  $opt->{referer}
#                   || charge_param('referer');

	## PSiGate does things a bit different, ensure we are OK
    $actual->{mv_credit_card_exp_month} =~ s/\D//g;
    $actual->{mv_credit_card_exp_month} =~ s/^0+//;
    $actual->{mv_credit_card_exp_year} =~ s/\D//g;
    $actual->{mv_credit_card_exp_year} =~ s/\d\d(\d\d)/$1/;

    $actual->{mv_credit_card_number} =~ s/\D//g;

#    my $exp = sprintf '%02d%02d',
#                        $actual->{mv_credit_card_exp_month},
#                        $actual->{mv_credit_card_exp_year};
    my $expmonth = sprintf '%02d',$actual->{mv_credit_card_exp_month};
    my $expyear = sprintf '%02d',$actual->{mv_credit_card_exp_year};

    my $bname = $actual->{b_fname}." ".$actual->{b_lname};

# Using mv_payment_mode for compatibility with older versions, probably not
# necessary.
    $opt->{transaction} ||= 'sale';
    my $transtype = $opt->{transaction};

    my %type_map = (
        auth                            =>	'1',
        sale                            =>      '0',
        settle                          =>      '2',
        void                            =>      '9',
    );

    if (defined $type_map{$transtype}) {
        $transtype = $type_map{$transtype};
    } else {
        return (
            MStatus => 'failure-hard',
            MErrMsg => errmsg('Invalid transaction type "%s"', $transtype),
        );
    }

    $amount = $opt->{total_cost} if $opt->{total_cost};

    if(! $amount) {
        $amount = Vend::Interpolate::total_cost();
        $amount = Vend::Util::round_to_frac_digits($amount,$precision);
    }

    $order_id = gen_order_id($opt);

    my %query = (
                    CardNumber          => $actual->{mv_credit_card_number},
                    MerchantID		=> $user,
                    Bname               => $bname,
                    Baddr1              => $actual->{b_address},
                    Bcity               => $actual->{b_city},
                    Bstate              => $actual->{b_state},
                    Bzip                => $actual->{b_zip},
                    Bcountry            => $actual->{b_country},
                    FullTotal    	=> $amount,
                    ExpMonth    	=> $expmonth,
                    ExpYear     	=> $expyear,
                    Oid                 => $actual->{order_id},
                    Bcompany            => $actual->{company},
                    Email               => $actual->{email},
                    Phone               => $actual->{phone_day},
                    IP                  => $CGI::remote_addr,
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

#::logDebug("PSiGate query: " . ::uneval(\%query));
    $opt->{extra_headers} = { Referer => $referer };

    my $thing    = post_data($opt, \%query);
    my $page     = $thing->{result_page};
    my $response = $thing->{status_line};

    # Minivend names are on the  left, PSiGate on the right
    my %result_map = ( qw/
            pop.status            PSi_Response_AppCod
            pop.error-message     PSi_Response_ErrMsg
            order-id              PSi_Response_Oid
            pop.order-id          PSi_Response_Oid
            pop.auth-code         PSi_Response_Code
            pop.avs_code          PSi_Response_Addnum
            pop.avs_zip           PSi_Response_Bzip
            pop.avs_addr          PSi_Response_Baddr1
    /
    );


#::logDebug(qq{\npsigate page: $page response: $response\n});

    my %result;
    @result{
		qw/
			PSi_Response_AppCode
			PSi_Response_ErrMsg
			PSi_Response_Code
			PSi_Response_TransTime
			PSi_Response_RefNo
			PSi_Response_OrdNo
			PSi_Response_SubTotal
			PSi_Response_ShipTotal
			PSi_Response_TaxTotal
			PSi_Response_Total
			PSi_Response_MerchantID
			PSi_Response_Oid
			PSi_Response_Userid
			PSi_Response_Bname
			PSi_Response_Bcompany
			PSi_Response_Baddr1
			PSi_Response_Baddr2
			PSi_Response_Bcity
			PSi_Response_Bstate
			PSi_Response_Bzip
			PSi_Response_Bcountry
			PSi_Response_Sname
			PSi_Response_Saddr1
			PSi_Response_Saddr2
			PSi_Response_Scity
			PSi_Response_Sstate
			PSi_Response_Szip
			PSi_Response_Scountry
			PSi_Response_Phone
			PSi_Response_Fax
			PSi_Response_ShipType
			PSi_Response_Comments
			PSi_Response_Email
			PSi_Response_ReferNum
			PSi_Response_ChargeType
			PSi_Response_Result
			PSi_Response_Addnum
			PSi_Response_IP
			PSi_Response_Country
			PSi_Response_State
			PSi_Response_Items
			PSi_Response_Weight
			PSi_Response_Carrier
			PSi_Response_ShipOn
			PSi_Response_TaxState
			PSi_Response_TaxZip
			PSi_Response_TaxOn
			PSi_Response_FullTotal
		/
		}
		 = split (/,/,$page);

#::logDebug(qq{psigate PSi_Response_ErrMsg=$result{PSi_Response_ErrMsg} response_code: $result{PSi_Response_AppCode}});

    for (keys %result_map) {
        $result{$_} = $result{$result_map{$_}}
            if defined $result{$result_map{$_}};
    }

    if ($result{PSi_Response_AppCode} == 1) {
    	$result{MStatus} = 'success';
		$result{'order-id'} ||= $opt->{order_id};
    }
	else {
    	$result{MStatus} = 'failure';
		delete $result{'order-id'};

        $result{MErrMsg} = errmsg($result{PSi_Response_ErrMsg});
		MErrMsg => errmsg('No account id'),
    }

    return (%result);
}

package Vend::Payment::PSiGate;

1;

