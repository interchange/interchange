# Vend::Payment::TCLink - Interchange TrustCommerce TCLink support
#
# $Id: TCLink.pm,v 1.9 2007-08-09 13:40:55 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 2002 TrustCommerce <developer@trustcommerce.com>
#
# by Dan Helfman <dan@trustcommerce.com> with code reused and inspired by
#       Mark Stosberg <mark@summersault.com>
#	Mike Heins
#	webmaster@nameastar.net
#	Jeff Nappi <brage@cyberhighway.net>
#	Paul Delys <paul@gi.alaska.edu>

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

package Vend::Payment::TCLink;

=head1 NAME

Vend::Payment::TCLink - Interchange TrustCommerce Support

=head1 SYNOPSIS

    &charge=trustcommerce
 
        or
 
    [charge mode=trustcommerce param1=value1 param2=value2]

=head1 PREREQUISITES

    Net::TCLink

http://www.trustcommerce.com/tclink.html and CPAN both have this module,
which actually does the bulk of the work. All that Vend::Payment::TCLink
does is to massage the payment data between Interchange and Net::TCLink.

=head1 DESCRIPTION

The Vend::Payment::TCLink module implements the trustcommerce() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules -- in theory (and even usually in practice) you
could switch from CyberCash to TrustCommerce with a few configuration 
file changes.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::TCLink

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<trustcommerce>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable MV_PAYMENT_MODE trustcommerce

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge mode=trustcommerce id=YourTrustCommerceID]

or

    Route trustcommerce id YourTrustCommerceID

or 

    Variable TRUSTCOMMERCE_ID YourTrustCommerceID

The active settings are:

=over 4

=item id

Your TrustCommerce customer ID, supplied by TrustCommerce when you sign up.
Global parameter is TRUSTCOMMERCE_ID.

=item secret

Your TrustCommerce customer password, supplied by TrustCommerce when you
sign up. Global parameter is TRUSTCOMMERCE_SECRET.

=item transaction

The type of transaction to be run. Valid values are:

    Interchange         TrustCommerce
    ----------------    -----------------
        auth            preauth
        return          credit
        sale            sale
        settle          postauth

Global parameter is TRUSTCOMMERCE_ACTION.

=item avs

Whether AVS (Address Verification System) is enabled. Valid values are "y"
for enabled and "n" for disabled. Global parameter is TRUSTCOMMERCE_AVS.

=item remap 

This remaps the form variable names to the ones needed by TrustCommerce. See
the C<Payment Settings> heading in the Interchange documentation for use.

=item test

Set this to C<TRUE> if you wish to operate in test mode, i.e. set the
TrustCommerce C<demo> query paramter to TRUE.

Examples: 

    Route trustcommerce test TRUE
        or
    Variable TRUSTCOMMERCE_TEST TRUE
        or 
    [charge mode=trustcommerce test=TRUE]

=back

=head2 Troubleshooting

Try the instructions above, then enable test mode. A test order should complete.

Disable test mode, then test in various TrustCommerce error modes by
using the credit card number 4222 2222 2222 2222.

Then try a sale with the card number C<4111 1111 1111 1111>
and a valid expiration date. The sale should be denied, and the reason should
be in [data session payment_error].

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::TrustCommerce

=item *

Make sure Net::TCLink is installed and working. You can test to see
whether your Perl thinks they are:

    perl -MNet::TCLink -e 'print "It works.\n"'

If it "It works." and returns to the prompt you should be OK (presuming
they are in working order otherwise).

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

If all else fails, TrustCommerce consultants are available to help you out.

See http://www.trustcommerce.com/contact.html for more information, or email
developer@trustcommerce.com

=back

=head1 BUGS

There is actually nothing *in* Vend::Payment::TrustCommerce. It changes
packages to Vend::Payment and places things there.

=head1 AUTHORS

Dan Helfman <dan@trustcommerce.com>, based on code by Mark Stosberg
<mark@summersault.com>, which was based on original code by Mike Heins.

=head1 CREDITS

    webmaster@nameastar.net
    Jeff Nappi <brage@cyberhighway.net>
    Paul Delys <paul@gi.alaska.edu>

=cut

BEGIN {
	eval {
		package Vend::Payment;
        	require Net::TCLink or die __PACKAGE__ . " requires Net::TCLink";
	};

	::logGlobal("%s payment module initialized", __PACKAGE__)
		unless $Vend::Quiet or ! $Global::VendRoot;
}

package Vend::Payment;

sub trustcommerce {
	my ($user, $amount) = @_;

	my $opt;
	if(ref $user) {
		$opt = $user;
		$user = $opt->{id} || $::Variable->{TRUSTCOMMERCE_ID} || undef;
		$secret = $opt->{secret} || $::Variable->{TRUSTCOMMERCE_SECRET} || undef;
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

#::logGlobal("actual map result: " . ::uneval($actual));
	if (! $user ) {
		$user    =  charge_param('id')
						or return (
							MStatus => 'failure-hard',
							MErrMsg => errmsg('No customer id'),
							);
	}
	
	$secret =  charge_param('secret') if ! $secret;

	my $precision = $opt->{precision} || 2;

	my $referer   =  $opt->{referer}
					|| charge_param('referer');

	$actual->{mv_credit_card_exp_month} =~ s/\D//g;
	$actual->{mv_credit_card_exp_year} =~ s/\D//g;
	$actual->{mv_credit_card_exp_year} =~ s/\d\d(\d\d)/$1/;
	$actual->{mv_credit_card_number} =~ s/\D//g;
	$actual->{b_zip} =~ s/\D//g;

	my $exp = sprintf '%02d%02d', $actual->{mv_credit_card_exp_month},
		$actual->{mv_credit_card_exp_year};

	my $transtype = $opt->{transaction} || $::Variable->{TRUSTCOMMERCE_ACTION};
	$transtype ||= 'sale';

	my %type_map = (
		auth		 	=>	'preauth',
		authorize		=>	'preauth',
		mauthcapture 		=>	'sale',
		mauthonly		=>	'preauth',
		return			=>	'credit',
		sale	 		=>	'sale',
		settle 			=>	'postauth',
		settle_prior 	=>	'postauth',
	);
	
	if (defined $type_map{$transtype}) {
		$transtype = $type_map{$transtype};
	}

	$amount = $opt->{total_cost} if $opt->{total_cost};
	
	if(! $amount) {
		$amount = Vend::Interpolate::total_cost();
		$amount = Vend::Util::round_to_frac_digits($amount,$precision);
	}
        $amount =~ s/\D//g;

	$order_id = gen_order_id($opt);

	$name = $actual->{b_fname} . ' ' . $actual->{b_lname};

        $avs = $opt->{avs} || $::Variable->{TRUSTCOMMERCE_AVS} || 'n';

	my %query = (
		amount		    	=> $amount,
		cc			=> $actual->{mv_credit_card_number},
		exp			=> $exp,
		demo			=> $opt->{test} || charge_param('test') || $::Variable->{TRUSTCOMMERCE_TEST},
		name			=> $name,
		address1		=> $actual->{b_address},
		city			=> $actual->{b_city},
		state			=> $actual->{b_state},
		zip			=> $actual->{b_zip},
		country			=> $actual->{b_country},
		action			=> $transtype,
		transid			=> $actual->{order_id},
		email			=> $actual->{email},
		phone			=> $actual->{phone_day},
		password	  	=> $secret,
		custid	  	   	=> $user,
		avs			=> $avs
	);

        # delete query keys with undefined values
	for (keys %query) {
        	delete $query{$_} unless $query{$_};
	}
        delete $query{country} if $query{country} eq 'US';

#::logGlobal("trustcommerce query: " . ::uneval(\%query));

	my %result = Net::TCLink::send(\%query);
	
	# Interchange names are on the left, TCLink on the right
	my %result_map = ( qw/
		pop.status		status
		order-id		transid
		pop.order-id		transid
		pop.avs_code		avs
	/
	);

#::logGlobal("trustcommerce response: " . ::uneval(\%result));

	for (keys %result_map) {
		$result{$_} = $result{$result_map{$_}}
			if defined $result{$result_map{$_}};
	}

	if ($result{status} eq 'approved') {
		$result{MStatus} = 'success';
	}
	else {
		$result{MStatus} = 'failure';
		delete $result{'order-id'};

		# NOTE: A lot more AVS codes could be checked for here.
	    	if ($result{avs} eq 'N') {
			my $msg = q{You must enter the correct billing address of your credit card.};
			$result{MErrMsg} = errmsg($msg);
	    	}
		else {
			my $msg = "TrustCommerce error: %s. Please call in your order or try again.";
	   		$result{MErrMsg} = errmsg($msg);
	    	}
	}

#::logGlobal("result given to interchange " . ::uneval(\%result));

	return (%result);
}

package Vend::Payment::TCLink;

1;
