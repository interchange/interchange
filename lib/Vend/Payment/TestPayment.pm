# Vend::Payment::TestPayment - Interchange payment test module
#
# $Id: TestPayment.pm,v 1.1 2002-09-08 15:40:07 kwalsh Exp $
#
# Copyright (C) 2002 Cursor Software Limited.
# All Rights Reserved.
#
# Author: Kevin Walsh <kevin@cursor.biz>
# Based on original code by Mike Heins <mheins@perusion.com>
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
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.
#
package Vend::Payment::TestPayment;

=head1 Interchange payment test module

Vend::Payment::TestPayment $Revision: 1.1 $

=head1 SYNOPSIS

    &charge=testpayment
 
	or
 
    [charge mode=testpayment param1=value1 param2=value2]

=head1 PREREQUISITES

None.

=head1 DESCRIPTION

The Vend::Payment::TestPayment module implements the testpayment() routine
for use with Interchange.  It's compatible on a call level with the other
Interchange payment modules -- in theory (and even usually in practice) you
could switch from TestPayment to another payment module with a few
configuration file changes.

The module will perform one of three actions:

=over 4

=item *

If the card number is 4111111111111111 then the transaction will be approved.

=item *

If the card number is 4111111111111129 then the transaction will be declined.

=item *

Any other card number will raise an error and the transaction will be declined.

=back

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::TestPayment

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<testpayment>.  To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  testpayment

It uses several of the standard settings from Interchange payment.  Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge mode=testpayment id=testid]

or

    Route testpayment id testid

or 

    Variable MV_PAYMENT_ID      testid

The active settings are:

=over 4

=item id

A test account ID, which can be any value you like.
Global parameter is MV_PAYMENT_ID.

=item secret

A test account password, which can be any value you like.
Global parameter is MV_PAYMENT_SECRET.  This is not needed for test
charges, using this module, but you may as well set it up anyway.

=item transaction

The type of transaction to be run.  Valid values are:

    auth
    return
    reverse
    sale
    settle
    void

Actually, the transaction type is ignored in this version, but you may as
well set it anyway.

=item remap 

This remaps the form variable names to the ones needed by TestPayment.  See
the C<Payment Settings> heading in the Interchange documentation for use.

=back

=head2 Troubleshooting

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::TestPayment

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

If all else fails, Cursor Software and other consultants are available to help
with integration for a fee.

=back

=head1 BUGS

There is actually nothing *in* Vend::Payment::TestPayment.  It changes packages
to Vend::Payment and places things there.

=head1 AUTHORS

Kevin Walsh <kevin@cursor.biz>
Based on original code by Mike Heins <mheins@perusion.com>

=cut

BEGIN {
    ::logGlobal("%s payment module loaded",__PACKAGE__)
	unless $Vend::Quiet;
}

$VERSION = substr(q$Revision: 1.1 $,10);

package Vend::Payment;

sub testpayment {
    my ($user,$amount) = @_;

    my $opt;
    if (ref $user){
	$opt = $user;
	$user = $opt->{id} || undef;
	$secret = $opt->{secret} || undef;
    }
    else{
	$opt = {};
    }
	
    my $actual;
    if ($opt->{actual}){
	$actual = $opt->{actual};
    }
    else{
	my (%actual) = map_actual();
	$actual = \%actual;
    }

#::logDebug("actual map result: " . ::uneval($actual));
    unless ($user){
	$user = charge_param('id') or return (
	    MStatus => 'failure-hard',
	    MErrMsg => errmsg('No account id'),
	);
    }
	
    $secret ||= charge_param('secret');

    my $precision = $opt->{precision} || 2;

    $actual->{mv_credit_card_exp_month} =~ s/\D//g;
    $actual->{mv_credit_card_exp_year} =~ s/\D//g;
    $actual->{mv_credit_card_number} =~ s/\D//g;

    my $exp = sprintf('%02d%02d',
	$actual->{mv_credit_card_exp_month},
	$actual->{mv_credit_card_exp_year},
    );

    $opt->{transaction} ||= 'sale';

    $amount = $opt->{total_cost} if $opt->{total_cost};
    unless ($amount){
        $amount = Vend::Interpolate::total_cost();
        $amount = Vend::Util::round_to_frac_digits($amount,$precision);
    }

    $order_id = gen_order_id($opt);

    my %result;

    if ($actual->{mv_credit_card_number} eq '4111111111111111'){
    	$result{'pop.status'} = 'success';
	$result{'pop.order-id'} = $opt->{order_id};
	$result{'pop.auth-code'} = 'test_auth_code';
    }
    elsif ($actual->{mv_credit_card_number} eq '4111111111111129'){
    	$result{'pop.status'} = 'failure';
	my $msg = $opt->{message_declined} ||
	    'TestPayment error: %s.  Please call in your order or try again.';
	$result{'pop.error-message'} = errmsg($msg,'Payment declined by the card issuer');
    }
    else{
    	$result{'pop.status'} = 'failure';
	delete $result{'pop.order-id'};
	delete $result{'order-id'};
	my $msg = $opt->{message_declined} ||
	    'TestPayment error: %s.  Please call in your order or try again.';
	$result{'pop.error-message'} = errmsg($msg,'Invalid test card number');
    }

    $result{MStatus} = $result{'pop.status'};
    $result{MErrMsg} = $result{'pop.error-message'} if $result{'pop.error-message'};
    $result{'order-id'} = $result{'pop.order-id'} if $result{'pop.order-id'};

    return %result;
}

package Vend::Payment::TestPayment;

1;
