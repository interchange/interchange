# Vend::Payment::Getitcard - Interchange Getitcard support
#
# $Id: Getitcard.pm,v 1.1 2008-04-17 15:48:12 racke Exp $
#
# Copyright (C) 2007,2008 Interchange Development Group
# Copyright (C) 2007,2008 Stefan Hornburg (Racke) <racke@linuxia.de>
# Copyright (C) 2007,2008 Jure Kodzoman (Yure) <jure@tenalt.com>
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

package Vend::Payment::Getitcard;

=head1 NAME

Vend::Payment::Getitcard - Interchange Getitcard Support

=head1 SYNOPSIS

&charge=getitcard

    or

[charge gateway=getitcard param1=value1 param2=value2]

=head1 PREREQUISITES

    Digest::SHA

    Net::SSLeay or LWP::UserAgent and Crypt::SSLeay

=head1 DESCRIPTION

This module adds support for purchases with prepaid cards issued
by Getitcard (http://www.getitcard.com/).

The Vend::Payment::Getitcard module implements the getitcard() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules -- in theory (and even usually in practice) you
could switch from CyberCash to Getitcard with a few configuration 
file changes.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::Getitcard

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<getitcard>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable MV_PAYMENT_MODE getitcard

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge mode=getitcard id=YourGetitcardID]

or

    Route getitcard id YourGetitcardID

or

    Variable MV_PAYMENT_ID YourGetitcardID

Required settings are C<id>.

The active settings are:

=over 4

=item host

Your Getitcard payment gateway host. Usually secure.getitcard.com.

=item secure

MD5 checksum required for valid transactions.

=item id

Store number assigned to your merchant account.

=item transaction

The type of transaction to be run. Valid values are:

    Interchange         Getitcard
    ----------------    -----------------
        auth            authorize
        sale            authorize + commit (inside authorize step)
	settle		commit
	void		cancel

Default is C<sale>.

=item order_id

Getitcard unique transact (transaction number), you receive as authorize result.

=item order_number

Interchange unique order_id, sent to Getitcard on all transactions

=back

=head2 Troubleshooting

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::Getitcard

=item *

Check the error logs, both catalog and global.

=item *

Make sure you have all the necessary parameters (you can consult getitcard docs).

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

=head1 EXAMPLES

This examples should work if you provide a valid card number,
and set variables MV_PAYMENT_ID, MV_PAYMENT_SECRET and MV_PAYMENT_CURRENCY.

=head2 Sale

[calc]$CGI->{mv_credit_card_number}='0123456789123456'[/calc]

[charge gateway=getitcard amount=12]

=head2 Authorize

[calc]$CGI->{mv_credit_card_number}='0123456789123456'[/calc]

[charge gateway=getitcard transaction=authorize amount=123]

=head2 Cancel

[charge gateway=getitcard transaction=cancel order_id=12345 order_number=123456]

=head2 Commit

[charge gateway=getitcard transaction=commit order_id=12345 order_number=123456]

=head1 AUTHORS

Stefan Hornburg (Racke) <racke@linuxia.de>

Jure Kodzoman (Yure) <jure@tenalt.com>

=cut


BEGIN {
	eval {
       	require Digest::SHA;
	};

	if ($@) {
		$msg = __PACKAGE__ . ' requires Digest::SHA.' . "\n";
		::logGlobal ($msg);
		die $msg;
	}

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

	::logGlobal("%s payment module initialized", __PACKAGE__)
		unless $Vend::Quiet or ! $Global::VendRoot;
}

package Vend::Payment;

sub getitcard {
	my ($user, $amount) = @_;
	my ($opt, $host, $currency);

#::logDebug('Entered getitcard function');

	if(ref $user) {
		$opt = $user;
		$user = $opt->{id} || undef;
		$host = $opt->{host} || undef;
		$currency = $opt->{currency} || undef;
		$secret = $opt->{secret} || undef;
		$transact = $opt->{order_id} || undef; # getitcard transact
		$order_number = $opt->{order_number}  || undef; # ic order_id
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

	# Use standard error message to display config error to the customer
	my $conf_error_msg = 'Configuration error. Please call customer support line.';

	# we need to check for customer id and keyfile
	# location, as these are the required parameters
	
	if (! $user ) {
		$user = charge_param('id')
			or return (
					   MStatus => 'failure-hard',
					   'pop.error-message' => 'No customer id',
					   MErrMsg => $conf_error_msg,
					  );
	}
	if (! $host ) {
		$host = charge_param('host') || 'secure.getitcard.com';
	}
	if (! $currency) {
		$currency = charge_param('currency')
			or return (
					   MStatus => 'failure-hard',
					   'pop.error-message' => 'No currency',
					   MErrMsg => $conf_error_msg,
					  );
	}
	if (! $secret) {
		$secret= charge_param('secret')
			or return (
					   MStatus => 'failure-hard',
					   'pop.error-message' => 'No secret defined (MD5)',
					   MErrMsg => $conf_error_msg,
					  );
	}
	
	my $precision = $opt->{precision} || 2;

	if ($precision > 2){
		return (
				MStatus => 'failure-hard',
				'pop.error-message' => 'Precision > 2 is not allowed.',
				MErrMsg => $conf_error_msg,
                );
	}

	my $transtype = $opt->{transaction} || charge_param('transaction') || 'sale';

	# match ic names (on the left) to getitcard method names (right)
	my %type_map = (
		auth		=>	'authorize',
		authorize	=>	'authorize',
		sale		=>	'sale',
		void		=>	'commit',
		return		=>	'cancel',
	);
	
	if (defined $type_map{$transtype}) {
		$transtype = $type_map{$transtype};
	}

	# Check if we have transact and order_number for commit or cancel
	if ($transtype =~ /(commit|cancel)/) {
		if (! $order_number) {
			$order_number = charge_param('order_number')
				or return (
						   MStatus => 'failure-hard',
						   'pop.error-message' => 'No interchange order number',
						   MErrMsg => $conf_error_msg,
						  );
		}
		if (! $transact){
			$transact = charge_param('order_id')
				or return (
						   MStatus => 'failure-hard',
						   'pop.error-message' => 'No transact number (order_id)',
						   MErrMsg => $conf_error_msg,
						  );
		}
	}

	# match functions (left) to script names (right)
	# this is because some functions use same script
	my %script_name_map = (
			'authorize'	=>	'authorize',
			'sale'		=>	'authorize',
			'cancel'	=>	'cancel',
			'commit'	=>	'commit',
		       );

	my $script_name = $script_name_map{$transtype} || 'authorize';

	$amount = $opt->{total_cost} unless $amount;
	if (! $amount) {
		$amount = Vend::Interpolate::total_cost();
	}

	# round digits so we don't get invalid amounts
	$amount = Vend::Util::round_to_frac_digits($amount,$precision);

	# This converts the amount to fit getitcard (ie 32.64 to 3264)
	$amount = sprintf("%d", $amount*100);

	$shipping = Vend::Interpolate::tag_shipping();
	$subtotal = Vend::Interpolate::subtotal();
	$salestax = Vend::Interpolate::salestax();

	# if we didn't get it with charge, get it from IC
	if (! $order_number){
		$order_number = gen_order_id($opt);
	}

	my $addrnum = $actual->{b_address1};
	my $bcompany = $Values->{b_company};
	my $scompany = $Values->{company};
	
	$addrnum =~ s/^(\d+).*$//g;
	$scompany =~ s/\&/ /g;
	$bcompany =~ s/\&/ /g;
	
	my %delmap = (
		POSTAUTH => [ 
				qw(
					cardnumber
				)
			],
	);

	my %query;
	if ($transtype =~/(authorize|sale)/) {

		# We need card number for authorization or sale
		$actual->{mv_credit_card_number} =~ s/\D//g;
		if (! $actual->{mv_credit_card_number}){
			return (
					MStatus => 'failure-hard',
					'pop.error-message' => 'Card number is not provided.',
					MErrMsg => $conf_error_msg,
			       );
		}

		%query = (
				account_id => $user,
				amount => $amount,
				cardnumber => $actual->{mv_credit_card_number},
				order_id => $order_number,
				enckey => '',
				commit => NO,
				multitransaction => -1,
				currency => $currency,
				user_ip => $Session->{ohost},
				text => '',
			    );

		if ($transtype eq 'sale'){
			# We want to do actual charge on sale type
			$query{commit}=YES;
		}

		
		# Compile SHA check which we send to gateway
		$query{enckey} = Digest::SHA::sha256_hex($query{account_id}
				. $query{amount}
				. $query{cardnumber}
				. $query{order_id}
				. $secret
				);

	}
	elsif ($transtype eq 'cancel'){
		%query = (
				account_id => $user,
				order_id => $order_number,
				transact => $transact,
				enckey => '',
				user_ip => $Session->{ohost},
			 );

		$query{enckey} = Digest::SHA::sha256_hex(
					$query{account_id}
					. $query{order_id}
					. $query{transact}
					. $secret
				);
	}
	elsif ($transtype eq 'commit'){
		%query = (
				account_id => $user,
				order_id => $order_number,
				transact => $transact,
				enckey => '',
				amount => $amount,
				user_ip => $Session->{ohost},
			 );

		$query{enckey} = Digest::SHA::sha256_hex(
					$query{account_id}
					. $query{order_id}
					. $query{transact}
					. $query{amount}
					. $secret
				);
	}
	# We have to uppercase the SHA key for Getitcard
 	$query{enckey}=uc($query{enckey});
	

	# delete query keys with undefined values
	for (keys %query) {
		delete $query{$_} unless $query{$_};
	}

#::logDebug("getitcard query: " . ::uneval(\%query));
	my $ret = post_data ({
				host => $host,
				protocol => 'https',
				script => "/getit/api/$script_name.api"
				}, \%query);

#::logDebug("getitcard result: $ret->{result_page}");

	# split the returned results into hash
	my %result = split(/[=&]/, $ret->{result_page});

	# Error codes and possible messages
	my %errors = (
		0 => 'Required parameter(s) not found.',
		10 => 'Encryption key is invalid.',
		20 => 'The card has insufficient funds.',
		30 => 'Approved.',
		40 => 'Transaction has been authorized.',
		50 => 'Transaction has been authorized, but is still missing amoount.',
		60 => 'Invalid cardnumber.',
		70 => 'Invalid currency - currency not supported.',
		80 => 'Authorized transaction not found.',
		90 => 'Order ID is invalid.',
		95 => 'Invalid merchant, merchant doesn\'t exist.',
		96 => 'Provided amount is too big and cannot be accepted.',
		97 => 'Destination card exceeds allowed amount.',
		100 => 'Error occured with Getitcard.',
		200 => 'Customer has exceeded failed attempts and has been blocked.',
		201 => 'Merchant has exceeded failed attempts and has been blocked.',
		300 => 'Could not find fee for getitcard by Creditcard purchase.',
		301 => 'Creditcard redeemer error.',
		302 => 'A possible fraud detected. The creditcard purchase has been annulled.', 
		303 => 'Credit card expired.',
		304 => 'CVC digits are missing.',
		305 => 'The creditcard is not accepted by redeemer.');

	$result{error_message}=$errors{ $result{result} };

	# check sha of authorization result
	my $sha_check = uc(Digest::SHA::sha256_hex($result{transact} . $result{result} . $secret));

	if($sha_check ne $result{checksum}){	
		return (
				MStatus => 'failure',
				MErrMsg => $call_error_msg,
				'pop.error-message' => "Data doesn't match the checksum.",
			);
	}

	# Interchange names are on the left, Getitcard on the right
	my %result_map = (
		order-number		=>	$order_number,
		order-id		=>	$transact,
		'pop.order-id'		=>	$transact,
		'pop.status'		=>	result,
		'pop.error-message'	=>	error_message,
	);

	for (keys %result_map) {
		$result{$_} = $result{$result_map{$_}}
			if defined $result{$result_map{$_}};
	}

	# authorize has different success code than
	# other functions
	
	my $success;
	if ($transtype eq 'authorize') {
		if ($result{result} == 40){
			$success = 1;
		}
	}else{
		if ($result{result} == 30){
			$success = 1;
		}
	}


	if ($success) {
		$result{'MStatus'} = 'success';
		$result{'MErrMsg'} = '';
	}
	else {
		# We will display error message to the customer
		# only if it's suitable for him to see it.
		my $error_message;
		if (
			$result{result} == 20 ||
			$result{result} == 60 ||
			$result{result} == 96 ||
			$result{result} == 97 ||
			$result{result} == 303
		){
			$error_message=$result{'error_message'}
		}

		my $msg = errmsg("Charge error: %s Please call in your order or try again.", $error_message);
		$result{MStatus} = 'failure';
		$result{MErrMsg} = $msg;
	}

#::logDebug("result given to interchange " . ::uneval(\%result));
	return (%result);
}

package Vend::Payment::Getitcard;

1;

