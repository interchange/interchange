# Vend::Payment::Linkpoint - Interchange Linkpoint support
#
# $Id: Linkpoint.pm,v 1.3 2005-02-19 04:00:14 jon Exp $
#
# Copyright (C) 2002 Stefan Hornburg (Racke) <racke@linuxia.de>
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

package Vend::Payment::Linkpoint;

=head1 NAME

Vend::Payment::Linkpoint - Interchange Linkpoint Support

=head1 SYNOPSIS

    &charge=linkpoint
 
        or
 
    [charge mode=linkpoint param1=value1 param2=value2]

=head1 PREREQUISITES

    LPERL

=head1 DESCRIPTION

The Vend::Payment::Linkpoint module implements the linkpoint() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules -- in theory (and even usually in practice) you
could switch from CyberCash to Linkpoint with a few configuration 
file changes.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::Linkpoint

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<linkpoint>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable MV_PAYMENT_MODE linkpoint

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge mode=linkpoint id=YourLinkpointID]

or

    Route linkpoint id YourLinkpointID

or 

    Variable MV_PAYMENT_ID YourLinkpointID

Required settings are C<id> and C<keyfile>.

The active settings are:

=over 4

=item host

Your LinkPoint Secure Payment Gateway (LSPG) hostname. Usually 
secure.linkpt.net (production) or staging.linkpt.net (testing).

=item keyfile

File name of the merchant security certificate. This file should contain the
RSA private key and the certificate, otherwise you get an error like
"Unable to open/parse client certificate file."

=item id

Store number assigned to your merchant account.

=item transaction

The type of transaction to be run. Valid values are:

    Interchange         Linkpoint
    ----------------    -----------------
        auth            preauth
        sale            sale

Default is C<sale>.

=back

=head2 Troubleshooting

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::Linkpoint

=item *

Make sure lpperl (v3.0.012+) is installed and working. You can test to see
whether your Perl thinks they are:

    perl -Mlpperl -e 'print "It works.\n"'

If it "It works." and returns to the prompt you should be OK (presuming
they are in working order otherwise).

=item *

Make sure curl is installed and working.  Lpperl uses curl to contact 
Linkpoint.

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

=back

=head1 BUGS

There is actually nothing *in* Vend::Payment::Linkpoint. It changes
packages to Vend::Payment and places things there.

=head1 AUTHOR

Stefan Hornburg (Racke) <racke@linuxia.de>
Ron Phipps <rphipps@reliant-solutions.com>

=cut
						
BEGIN {
	eval {
		package Vend::Payment;
        	require lpperl or die __PACKAGE__ . " requires LPPERL";
	};

	if ($@) {
		$msg = __PACKAGE__ . ' requires LPPERL';
		::logGlobal ($msg);
		die $msg;
	}
	
	::logGlobal("%s payment module initialized", __PACKAGE__)
		unless $Vend::Quiet or ! $Global::VendRoot;
}

package Vend::Payment;

sub linkpoint {
	my ($user, $amount) = @_;

	my $opt;
	my $keyfile;
	my $host;
	
	if(ref $user) {
		$opt = $user;
		$user = $opt->{id} || undef;
		$keyfile = $opt->{keyfile} || undef;
		$host = $opt->{host} || undef;
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
#::logDebug("opt map result: " . ::uneval($opt));

	# we need to check for customer id and keyfile
	# location, as these are the required parameters
	
	if (! $user ) {
		$user = charge_param('id')
			or return (
					   MStatus => 'failure-hard',
					   MErrMsg => errmsg('No customer id'),
					  );
	}

	if (! $keyfile ) {
		$keyfile = charge_param('keyfile')
			or return (
					   MStatus => 'failure-hard',
					   MErrMsg => errmsg('No certificate file'),
					  );
	}
	
	
	if (! $host ) {
		$host = charge_param('host') || 'secure.linkpt.net';
	}

	my $precision = $opt->{precision} || 2;

	$actual->{mv_credit_card_exp_month} =~ s/\D//g;
	$actual->{mv_credit_card_exp_year} =~ s/\D//g;
	$actual->{mv_credit_card_exp_year} =~ s/\d\d(\d\d)/$1/;
	$actual->{mv_credit_card_number} =~ s/\D//g;
	$actual->{b_zip} =~ s/\D//g;

	my $exp = sprintf '%02d%02d', $actual->{mv_credit_card_exp_month},
		$actual->{mv_credit_card_exp_year};

	my $transtype = $opt->{transaction} || charge_param('transaction') || 'sale';

	my %type_map = (
		auth		 	=>	'PREAUTH',
		authorize		=>	'PREAUTH',
		mauthcapture 	=>	'SALE',
		mauthonly		=>	'PREAUTH',
		sale	 		=>	'SALE',
	);
	
	if (defined $type_map{$transtype}) {
		$transtype = $type_map{$transtype};
	}

	$amount = $opt->{total_cost} unless $amount;
	
	if(! $amount) {
		$amount = Vend::Interpolate::total_cost();
		$amount = Vend::Util::round_to_frac_digits($amount,$precision);
	}

	$amount =~ s/\D//g;

	$amount = int ($amount / 100) . '.' . ($amount % 100);
	$shipping = Vend::Interpolate::tag_shipping();
	$subtotal = Vend::Interpolate::subtotal();
	$salestax = Vend::Interpolate::salestax();
	$order_id = gen_order_id($opt);

	my $addrnum = $actual->{b_address1};
	my $bcompany = $Values->{b_company};
	my $scompany = $Values->{company};
	
	$addrnum =~ s/^(\d+).*$//g;
	$scompany =~ s/\&/ /g;
	$bcompany =~ s/\&/ /g;
	
	my %varmap = ( qw /
				   name b_name
				   address1 b_address1
				   address2 b_address2
				   city b_city
				   state b_state
				   zip b_zip
				   country b_country
				   email email
				   phone phone_day
				   sname name
				   saddress1 address1
				   saddress2 address2
				   scity city
				   sstate state
				   szip zip
				   scountry country
				   / );

	my %query =
		(host => $host,
		 port => '1129',
		 configfile => $user,
		 keyfile => $keyfile,
		 result => 'LIVE',
		 terminaltype => 'UNSPECIFIED',
		 shipping => $shipping,
		 chargetotal => $amount,
		 subtotal => $subtotal,
		 tax => $salestax,
		 vattax => '0.00',
		 cardnumber => $actual->{mv_credit_card_number},
		 cardexpmonth => sprintf ("%02d", $actual->{mv_credit_card_exp_month}),
		 cardexpyear => sprintf ("%02d", $actual->{mv_credit_card_exp_year}),
		 addrnum => $addrnum,
		 debbugging => $opt->{debuglevel},
		 company => $bcompany,
		 scompany => $scompany, # API is broken for Shipping Company per Linkpoint support
		);

    for (keys %varmap) {
        $query{$_} = $actual->{$varmap{$_}};
    }
    
    $query{saddress2} = $actual->{address1} . ' ' . $actual->{address2}; # API is broken for Shipping Address Line 1, put line 1 and line 2 in API line 2 per Linkpoint support
	
    # delete query keys with undefined values
	for (keys %query) {
        	delete $query{$_} unless $query{$_};
	}

#::logDebug("linkpoint query: " . ::uneval(\%query));

	my $lperl = new LPPERL();

	my %result = $lperl->curl_process(\%query);
	
	# Interchange names are on the left, Linkpoint on the right
	my %result_map = ( qw/
					   order-id       r_ordernum
					   pop.order-id   r_ordernum
					   pop.auth-code  r_code
					   pop.avs_code   r_avs
					   pop.status     r_code
            				   pop.error-message     r_error
	/
	);

#::logDebug("linkpoint response: " . ::uneval(\%result));

	for (keys %result_map) {
		$result{$_} = $result{$result_map{$_}}
			if defined $result{$result_map{$_}};
	}

	if ($result{'r_approved'} eq "APPROVED") {
		$result{'MStatus'} = 'success';
		$result{'MErrMsg'} = $result{'r_code'};
	} else {
		my $msg = errmsg("Charge error: %s Please call in your order or try again.",
			$result{'r_error'},
		);

		$result{MStatus} = 'failure';
		$result{MErrMsg} = $msg;
	}

#::logDebug("result given to interchange " . ::uneval(\%result));

	return (%result);
}

package Vend::Payment::Linkpoint;

1;
