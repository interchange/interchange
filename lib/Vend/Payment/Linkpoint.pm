# Vend::Payment::Linkpoint - Interchange Linkpoint support
#
# $Id: Linkpoint.pm,v 1.2 2004-06-07 20:59:18 mheins Exp $
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

    Variable LINKPOINT_ID YourLinkpointID

Required settings are C<host>, C<keyfile> and C<bin>.

The active settings are:

=over 4

=item host

Your LinkPoint Secure Payment Gateway (LSPG) hostname. Usually secure.linkpt.net (production) or staging.linkpt.net (testing).

=item keyfile

File name of the merchant security certificate. This file should contain the
RSA private key and the certificate, otherwise you get an error like
"Unable to open/parse client certificate file."

=item bin

File name of the LinkPoint binary. You get an "Unknown error" if you
specify another executable.

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

Make sure LPERL is installed and working. You can test to see
whether your Perl thinks they are:

    perl -MLPERL -e 'print "It works.\n"'

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

=back

=head1 BUGS

There is actually nothing *in* Vend::Payment::Linkpoint. It changes
packages to Vend::Payment and places things there.

=head1 AUTHOR

Stefan Hornburg (Racke) <racke@linuxia.de>

=cut
						
BEGIN {
	eval {
		package Vend::Payment;
        	require LPERL or die __PACKAGE__ . " requires LPERL";
	};

	if ($@) {
		$msg = __PACKAGE__ . ' requires LPERL';
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
	
	if(ref $user) {
		$opt = $user;
		$user = $opt->{id} || undef;
		$keyfile = $opt->{keyfile} || undef;
		$bin = $opt->{bin} || undef;
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

	# we need to check for customer id, keyfile and binary
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

	if (! $bin ) {
		$bin = charge_param('bin')
			or return (
					   MStatus => 'failure-hard',
					   MErrMsg => errmsg('No LinkPoint binary'),
					  );
	}

	unless (-x $bin) {
		return (
				MStatus => 'failure-hard',
				MErrMsg => errmsg('LinkPoint binary not executable'),
			   );
	
	}
	
	unless ($opt->{host}) {
		$opt->{host} = charge_param('host') || 'secure.linkpt.net';
	}
	
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

	my $transtype = $opt->{transaction} || charge_param('transaction') || 'sale';

	my %type_map = (
		auth		 	=>	'preauth',
		authorize		=>	'preauth',
		mauthcapture 	=>	'sale',
		mauthonly		=>	'preauth',
		sale	 		=>	'sale',
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
	
	my %varmap = ( qw /
				   baddr1 b_address1
				   baddr2 b_address2
				   bcity b_city
				   bcountry b_country
				   bname b_name
				   bstate b_state
				   bzip b_zip
				   email email
				   phone phone_day
				   saddr1 address1
				   saddr2 address2
				   scity city
				   scountry country
				   sname name
				   sstate state
				   szip zip
				   / );

	my %query =
		(hostname => $opt->{host},
		 port => '1139',
		 storename => $user,
		 keyfile => $keyfile,		 
		 shipping => $shipping,
		 chargetotal => $amount,
		 subtotal => $subtotal,
		 tax => $salestax,
		 cardnumber	=> $actual->{mv_credit_card_number},
		 expmonth => sprintf ("%02d", $actual->{mv_credit_card_exp_month}),
		 expyear => sprintf ("%02d", $actual->{mv_credit_card_exp_year}),
		 bcompany => $Values->{company},
		 scompany => $Values->{company},
		 debuglevel => $opt->{debuglevel},
		);

	for (keys %varmap) {
        $query{$_} = $actual->{$varmap{$_}};
    }
	
    # delete query keys with undefined values
	for (keys %query) {
        	delete $query{$_} unless $query{$_};
	}

#::logDebug("linkpoint query: " . ::uneval(\%query));

    my $tempfile = "$Vend::Cfg->{ScratchDir}/linkpoint.$order_id";
	my $lperl = new LPERL($bin, "FILE", $tempfile);

	my %result;

	if ($transtype eq 'preauth') {
		%result = $lperl -> CapturePayment (\%query);
	} elsif ($transtype eq 'sale') {
		%result = $lperl->ApproveSale(\%query);
	} else {
		return (
				MStatus => 'failure-hard',
				MErrMsg => errmsg('Unrecognized transaction: %s', $transtype),
			   );
	}
	
	# Interchange names are on the left, Linkpoint on the right
	my %result_map = ( qw/
					   order-id       neworderID
					   pop.order-id   neworderID
					   pop.auth-code  code
					   pop.avs_code   AVSCode
	/
	);

#::logDebug("linkpoint response: " . ::uneval(\%result));

	for (keys %result_map) {
		$result{$_} = $result{$result_map{$_}}
			if defined $result{$result_map{$_}};
	}

	if ($result{statusCode}) {
		$result{MStatus} = 'success';
	}
	else {
		$result{MStatus} = 'failure';
	   	$result{MErrMsg} = $result{statusMessage} || 'Unknown error';
	}

#::logDebug("result given to interchange " . ::uneval(\%result));

	return (%result);
}

package Vend::Payment::Linkpoint;

1;
