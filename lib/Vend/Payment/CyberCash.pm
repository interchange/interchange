# Vend::Payment::CyberCash - Interchange CyberCash support
#
# $Id: CyberCash.pm,v 2.7 2007-08-09 13:40:55 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1999-2002 Red Hat, Inc.

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
#
# Connection routine for CyberCash version 3 using the 'MCKLib3_2 Direct'
# method.

package Vend::Payment::CyberCash;

$VERSION = substr(q$Revision: 2.7 $, 10);

=head1 NAME

Vend::Payment::CyberCash - Interchange CyberCash Support

=head1 SYNOPSIS

    &charge=cybercash
 
        or
 
    [charge mode=cybercash param1=value1 param2=value2]
 
        or
 
    $Tag->charge('cybercash', $opt);

=head1 PREREQUISITES

CyberCash connection kit V3.2.0.4

=head1 DESCRIPTION

The Vend::Payment::CyberCash module implements the cybercash() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules -- in theory (and even usually in practice) you
could switch from Authorize.net to CyberCash with a few configuration 
file changes.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::CyberCash

This I<should> be in interchange.cfg or a file included from it, but
it is actually in by default to maintain backward compatibility with
legacy CyberCash installations.

Make sure CreditCardAuto is off (default in Interchange demos).

Make sure the CyberCash Merchant connection kit is installed and working.
It requires the following steps:

=over 4

=item 1.

Obtain the CyberCash modules, prefereably version 3.2.0.4 though
3.2.0.5 and above should work if you add "DebugFile /dev/null" in
interchange.cfg. Ask around on the list if you need older versions.

=item 2.

Install the modules, then find the directory where they are and
copy them to /path_to_interchange/lib. Include the following files:

    CCMckDirectLib3_2.pm  CCMckLib3_2.pm  MCKencrypt
    CCMckErrno3_2.pm      MCKdecrypt      computeMD5hash

Make sure the program files (non-.pm) are executable.

=item 3.

Edit CC*.pm to adjust the paths for MCKencrypt, MCKdecrypt, and
computeMD5hash.

  in CCMckDirectLib3_2.pm:
    $MCKencrypt = "/path_to_interchange/lib/MCKencrypt";
    $MCKdecrypt = "/path_to_interchange/lib/MCKdecrypt";
  
  in CCMckLib3_2.pm:
    $computehash = "/path_to_interchange/lib/computeMD5hash";

=item 4.

Restart Interchange and make sure you get the message:

    CyberCash module found (Version 3.x)

=back

The mode can be named anything, but the C<gateway> parameter must be set
to C<cybercash>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  cybercash

It uses any of the applicable standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<configfile> parameter would
be specified by:

    [charge mode=cybercash configfile="/path/to/the/merchant_conf"]

or

    Route cybercash configfile /path/to/the/merchant_conf

or 

    Variable MV_PAYMENT_CONFIGFILE    /path/to/the/merchant_conf

The active settings are:

=over 4

=item configfile

Your CyberCash merchant_conf file, usually created when you installed the MCK.
Global parameter is MV_PAYMENT_CONFIGFILE.

=item precision

The number of decimal digits to be included in the amount. Default is 2.

=item currency

The international currency code to use. Default is C<usd>. Must be supported
by CyberCash.

=back

Items supported, but never normally used, are:

=over 4

=item host

The CyberCash host to use. Default is set in the merchant_conf file, and is
not normally changed by the user. No global parameter is used for fear of
conflict with another payment gateway -- must be set in the Route or
direct option.

=item transaction

The type of transaction to be run. Valid values are:

    Interchange mode    CyberCash mode
    ----------------    -----------------
    sale                mauthcapture
    auth                mauthonly

IMPORTANT NOTE: In most cases, you cannot control your transaction type,
it is set at http://amps.cybercash.com.

=item remap 

This remaps the form variable names to the ones needed by CyberCash. See
the payment documentation for details.

=back

=head2 Troubleshooting

Try the instructions above, then enable test mode at http://amps.cybercash.com.
A test order should complete. Exam

Then try a sale with the card number C<4111 1111 1111 1111>
and a valid expiration date. The sale should be denied, and the reason should
be in [data session payment_error].

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::CyberCash

=item *

Make sure the CyberCash Merchant connection kit is installed and working. Test
with CyberCash's supplied routines.

=item *

Check the error logs, both catalog and global.

=item *

Make sure you set your payment parameters properly. At the minimum, you
will need:

    Route  cybercash   configfile   /path/to/merchant_conf

=item *

Make sure you have a payment mode set if you are not calling it with
C<&charge=cybercash>:

    Variable  MV_PAYMENT_MODE  cybercash

Everything is case-sensitive, make sure values match.

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

There is actually nothing *in* Vend::Payment::CyberCash. It changes packages
to Vend::Payment and places things there.

=head1 AUTHORS

Mike Heins

=head1 CREDITS

    Jeff Nappi <brage@cyberhighway.net>
    Paul Delys <paul@gi.alaska.edu>
    webmaster@nameastar.net
    Ray Desjardins <ray@dfwmicrotech.com>
    Nelson H. Ferrari <nferrari@ccsc.com>

=cut

package Vend::Payment;

use CCMckLib3_2			qw/InitConfig/;
use CCMckDirectLib3_2	qw/SendCC2_1Server doDirectPayment/;
use CCMckErrno3_2		qw/MCKGetErrorMessage/;

use strict;

my $ver = $CCMckLib3_2::VERSION || '3.x';

$Vend::CC3 = 1;
::logGlobal({}, "CyberCash module found (Version %s)", $ver )
	unless $Vend::Quiet or ! $Global::VendRoot;

sub cybercash {
		my ($opt) = @_;

		my %actual;
		if (ref $opt->{actual}) {
			%actual = %{$opt->{actual}};
		}
		else {
			%actual = map_actual();
		}

		my $amount  = $opt->{amount};
		my $orderID = $opt->{order_id};
		my $cfg	    = $opt->{configfile} || charge_param('configfile');

#::logDebug("cybercash: amount=$amount orderID=$orderID");
#::logDebug("cybercash: actual=" . ::uneval(\%actual));

		# Cybercash 3.x libraries to be used.
		# Initialize the merchant configuration file
		my $status = InitConfig($cfg);
		if ($status != 0) {
			return (
					MStatus => 'failure-hard',
					MErrMsg => MCKGetErrorMessage($status),
			);
		}

		my $cc_config = \%CCMckLib3_2::Config;

		my $host = $opt->{host} || $cc_config->{CCPS_HOST};

		my $sendurl = $host . 'directcardpayment.cgi';

		my %paymentNVList;
		$paymentNVList{'mo.cybercash-id'}	 = $cc_config->{CYBERCASH_ID};
		$paymentNVList{'mo.version'}		 = $CCMckLib3_2::MCKversion;

		$paymentNVList{'mo.signed-cpi'}      = 'no';
		$paymentNVList{'mo.order-id'}        = $orderID;
		$paymentNVList{'mo.price'}           = $amount;

		$paymentNVList{'cpi.card-number'}	= $actual{mv_credit_card_number};
		$paymentNVList{'cpi.card-exp'}		= $actual{mv_credit_card_exp_all};
		$paymentNVList{'cpi.card-name'}		= $actual{b_name};
		$paymentNVList{'cpi.card-address'}	= $actual{b_address};
		$paymentNVList{'cpi.card-city'}		= $actual{b_city};
		$paymentNVList{'cpi.card-state'}	= $actual{b_state};
		$paymentNVList{'cpi.card-zip'}		= $actual{b_zip};
		$paymentNVList{'cpi.card-country'}	= $actual{b_country};

#::logDebug("sendurl=$sendurl");
#::logDebug("list=" . ::uneval(\%paymentNVList));

		my (%tokenlist);
		my ($POPref, $tokenlistref ) = 
						  doDirectPayment( $sendurl, \%paymentNVList );
		
		$POPref->{MStatus}    = $POPref->{'pop.status'};
		$POPref->{MErrMsg}    = $POPref->{'pop.error-message'};
		$POPref->{'order-id'} = $POPref->{'pop.order-id'};

		# other values found in POP which might be used in some way:
		#		$POP{'pop.auth-code'};
		#		$POP{'pop.ref-code'};
		#		$POP{'pop.txn-id'};
		#		$POP{'pop.sale_date'};
		#		$POP{'pop.sign'};
		#		$POP{'pop.avs_code'};
		#		$POP{'pop.price'};

		return %$POPref;
}

package Vend::Payment::CyberCash;

1;
