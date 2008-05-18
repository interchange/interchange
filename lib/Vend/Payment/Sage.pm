# Vend::Payment::Sage - Interchange Sage Support
#
# $Id: Sage.pm,v 1.1 2008-03-18 16:09:16 docelic Exp $
#
# Copyright (C) 2008 Spinlock Solutions, http://www.spinlocksolutions.com/
# Copyright (C) 2008 Prince Services, http://www.princeinternet.com/
# Copyright (C) 2008 Interchange Development Group, http://www.icdevgroup.org/
#
# Written by Davor Ocelic, based on code by Cameron Prince,
# Mark Johnson and Mike Heins.

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

package Vend::Payment::Sage;

=head1 NAME

Vend::Payment::Sage - Interchange Sage Support

=head1 SYNOPSIS

    &charge=sage
 
        or
 
    [charge route=sage param1=value1 param2=value2]

=head1 PREREQUISITES

  Net::SSLeay
 
    or
  
  LWP::UserAgent and Crypt::SSLeay

Only one of these need be present and working.

=head1 DESCRIPTION

The Vend::Payment::Sage module implements the sage() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules -- in theory (and even usually in practice) you
could switch from CyberCash to Sage with a few configuration 
file changes.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::Sage

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<sage>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  sage

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge route=sage id=YourSage]

or

    Route sage id YourSageID

or 

    Variable MV_PAYMENT_ID      YourSageID

The active settings are:

=over 4

=item id

Your Sage account ID, supplied by Sage when you sign up.
Global parameter is MV_PAYMENT_ID.

=item remap 

This remaps the form variable names to the ones needed by Sage. See
the C<Payment Settings> heading in the Interchange documentation for use.

=back

=head2 Troubleshooting

Try the instructions above, then enable test mode. A test order should complete.

Then move to live mode and try a sale with the card number C<4111 1111 1111 1111>
and a valid expiration date. The sale should be denied, and the reason should
be in [data session payment_error].

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::Sage

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

Make sure you set your account ID properly.  

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
See http://www.icdevgroup.org/

=item *

Sage technical docs are available at
http://www.sagepayments.com/Support/Documentation.aspx

=back

=head1 BUGS

There is actually nothing *in* Vend::Payment::Sage. It changes packages
to Vend::Payment and places things there.

=head1 AUTHORS

Davor Ocelic, based on original code by Cameron Prince,
Mark Johnson and Mike Heins.

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

sub sage {
	my ($opt, $amount) = @_;

	my %actual;
	if($opt->{actual}) {
		%actual = %{$opt->{actual}};
	}
	else {
		%actual = map_actual();
	}

	my $id     = $opt->{id}     || charge_param('id');
	my $secret = $opt->{secret} || charge_param('secret');
	my $method = $opt->{method} || charge_param('method') || 'CC';

	$opt->{submit_url} =
		'https://www.sagepayments.net/cgi-bin/eftBankcard.dll?transaction';

	if (! $id) {
		return (
				MStatus => 'failure-hard',
				MErrMsg => errmsg('No account id'),
		)
	}

	my @override = qw/
		order_id
		auth_code
		mv_credit_card_exp_month
		mv_credit_card_exp_year
		mv_credit_card_number
		mv_credit_card_cvv2
		/;
	for(@override) {
		next unless defined $opt->{$_};
		$actual->{$_} = $opt->{$_};
	}

	$opt->{precision} ||= charge_param('precision') || 2;

	$actual{mv_credit_card_exp_month} =~ s/\D//g;
	$actual{mv_credit_card_exp_month} =~ s/^0+//;
	$actual{mv_credit_card_exp_year} =~ s/\D//g;
	$actual{mv_credit_card_number} =~ s/\D//g;

	my %type_map = (
			# Code: 01 = Sale, 02 = AuthOnly, 03 = Force/PriorAuthSale
			# 04 = Void, 06 = Credit, 11 = PriorAuthSale by T_Reference
			AUTH_CAPTURE      =>  '01',
			AUTH_ONLY         =>  '02',
			#CAPTURE_ONLY      =>  'CAPTURE_ONLY',
			PRIOR_AUTH_CAPTURE=>  '03',
			VOID              =>  '04',
			CREDIT            =>  '06',

			auth              =>  '02',
			authorize         =>  '02',
			mauthcapture      =>  '01',
			mauthonly         =>  '02',
			return            =>  '06',
			#settle_prior      =>  '03',
			sale              =>  '01',
			#settle            =>  'CAPTURE_ONLY',
			void              =>  '04',
	);

	my $transtype = $opt->{transaction} || 'sale';
	if (defined $type_map{$transtype}) {
		$transtype = $type_map{$transtype};
	}

	my %allowed_map = (
		CC => {
			'01' => 1,
			'02' => 1,
			'03' => 1,
			'04' => 1,
			'06' => 1,
			#CAPTURE_ONLY => 1,
		},
		# Enable when supported:
		#VCHECK => {
		#	'01' => 1,
		#	'04' => 1,
		#	'06' => 1,
		#},
	);

	if(! $allowed_map{$method}) {
		::logError("Unknown Sage method $method");
		return (
				MStatus => 'failure-hard',
				MErrMsg => errmsg('Unknown Sage method ' . $method),
		)
	}
	elsif(! $allowed_map{$method}{$transtype}) {
		::logError("Unknown Sage transtype $transtype for $method");
		return (
				MStatus => 'failure-hard',
				MErrMsg => errmsg('Unknown Sage transtype ' . $transtype),
		)
	}
   
	$amount = $opt->{total_cost} if $opt->{total_cost};
	if(! $amount) {
		$amount = Vend::Interpolate::total_cost();
	}
	$amount = Vend::Util::round_to_frac_digits($amount,$precision);

	my $gen;
	if($opt->{test} and $gen = charge_param('generate_error') ) {
#::logDebug("trying to generate error");
		$actual{mv_credit_card_number} = '4111111111111112'
			if $gen =~ /number/;
		$actual{mv_credit_card_exp_year} = '00'
			if $gen =~ /date/;
	}

	# $exp = MMYY
	my $exp =
		substr(('0' . $actual{mv_credit_card_exp_month}), -2) .
		substr($actual{mv_credit_card_exp_year}, -2);

	# No-op if $opt->{order_id}
	gen_order_id($opt);

	my %values = (
		### Required
		M_id               => $id, # 12 Digit Merchant ID
		M_key              => $secret, # 12 Digit Merchant Key
		C_name             => $actual{b_name}, # Cardholder
		C_address          => $actual{b_address}, # Billing Address
		C_city             => $actual{b_city}, # Billing... 
		C_state            => $actual{b_state}, # Billing... 
		C_zip              => $actual{b_zip}, # Billing... 
		C_email            => $actual{email},, # Email address
		C_cardnumber       => $actual{mv_credit_card_number}, # Account Number
		C_exp              => $exp, # Expiration Date (MMYY)
		T_amt              => $amount, # Transaction Amount (######0.00)
		T_code             => $transtype, # Transaction Processing Code

		### Optional
		C_country          => $actual{b_country},
		T_ordernum         => $opt->{order_id}, # Unique 1-20 Digit Order Number
		#T_auth             => , # Previous (VOICE) Authorization Code
		#T_reference        => , # Unique Reference (void & prior auth T_code)
		#T_trackdata        => , # Track 2 Data for POS Applications
		C_cvv              => $actual{mv_credit_card_cvv2}, # CVV2
		#T_customer_number  => , #
		#T_tax              => , # Tax Amount (######0.00)
		#T_shipping         => , # Shipping Amount (######0.00)
		#C_ship_name        => , # Shipping Recipient
		#C_ship_address     => , # Shipping...
		#C_ship_city        => , # Shipping...
		#C_ship_state       => , # Shipping...
		#C_ship_zip         => , # Shipping...
		#C_ship_country     => , # Shipping...
		C_telephone        => $actual{phone_day}, # Customer Telephone Number
		#C_fax              => , # Customer Fax Number
		#T_recurring        => , # 1=Add as a Recurring Transaction
		#T_recurring_amount => , # Recurring Amount
		#T_recurring_type   => , # 1=Monthly, 2=Daily
		#T_recurring_interval=> , # Recurring Interval 
		#T_recurring_non_business_days=> , # 0=After, 1=Before, 2=That Day
		#T_recurring_start_date=> , # Recurring Start Date MM/DD/YYYY
		#T_recurring_indefinite=> , # 1=Yes Indefinite, 0=No
		#T_recurring_times_to_process=> , # Times To Process the Recurring Transaction
		#T_recurring_group  => , # Recurring Group ID
		#T_recurring_payment=> , # Merchant initiated recurring transaction
		);

	my %result;

#::logDebug("sending query: " . ::uneval(\%values));

	my $thing         = post_data($opt, \%values);
	my $header_string = $thing->{header_string};
	my $result_line = $thing->{result_page};

#::logDebug("request returned verbatim: $result_line");

	# Parse result_line
	@result{
		'STX',
		'Approval Indicator',
		'Code',
		'Message',
		'Front-End',
		'CVV Indicator',
		'AVS Indicator',
		'Risk Indicator',
		'Reference',
		'FS1',
	}  = unpack('AAA6A32A2AAA2A10A',
		substr($result_line, 0, 57,''));

	@result{
		'FS2',
		'Recurring Indicator',
		'FS3',
		'ETX',
	}  = unpack('AAAA',
		substr($result_line, -4, 4,''));
	
	$result{Message} =~ s/^\s+//;

	# Finally only the one variable-length field is left
	# in $result_line, and it's the order number
	$result{'Order Number'} = $result_line;

	if ( $result{'Approval Indicator'} eq 'A' ) {
		$result{MStatus} = 'success';
		$result{'order-id'} = $result{'Order Number'} || $opt->{order_id};
	} else {
		$result{MStatus} = 'denied';
		$result{MErrMsg} = ucfirst lc $result{Message};
#::logDebug("Sage Error: " . $result{Message});
	}

#::logDebug("request returned: " . uneval(\%result));

	return %result;
}

package Vend::Payment::Sage;

1;
