# Vend::Payment::Merchantware - Interchange Merchant Warehouse support
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

package Vend::Payment::Merchantware;

=head1 NAME

Vend::Payment::Merchantware - Interchange Merchant Warehouse Support

=head1 SYNOPSIS

    &charge=merchantware
 
        or
 
    [charge mode=merchantware param1=value1 param2=value2]

=head1 PREREQUISITES

 SOAP::Lite

=head1 DESCRIPTION

The Vend::Payment::Merchantware module implements the merchantware() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules -- in theory (and even usually in practice) you
could switch from a different payment module to Merchantware with a few
configuration file changes.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::Merchantware

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<merchantware>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  merchantware

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge mode=merchantware id=YourMerchantwareID]

or

    Route merchantware id YourMerchantwareID

or with only Merchantware as a payment provider

    Variable MV_PAYMENT_ID      YourMerchantwareID

The active settings are:

=over 4

=item id

Your account ID, supplied by Merchant Warehouse when you sign up.
Global parameter is MV_PAYMENT_ID.

=item secret

Your account key (not password), provided by Merchant Warehouse when you
sign up. Global parameter is MV_PAYMENT_SECRET.

=item partner

Your account name, selected by you or provided by Merchant Warehouse
when you sign up. Global parameter is MV_PAYMENT_PARTNER.

=item transaction

The type of transaction to be run. Valid values are:

    Interchange         Merchantware
    ----------------    -----------------
        auth            PreAuthorizationKeyed
        sale            SaleKeyed
        credit          Refund
        void            Void
        settle          PostAuthorization  (from previous auth transaction)
        repeat_sale     RepeatSale  (from previous sale or auth transaction)
        void_auth       VoidPreAuthorization
        settle_batch    SettleBatch
        level2_sale     Level2SaleKeyed

Default is C<sale>.

=item check_sub

Name of a Sub or GlobalSub to be called after the result hash has been
received. A reference to the modifiable result hash is passed into the
subroutine, and it should return true (in the Perl truth sense) if its
checks were successful, or false if not. The transaction type is passed
in as a second arg, if needed.

This can come in handy since, strangely, MerchantWare has no option to
decline a charge when AVS or CSC data come back negative.

If you want to fail based on a bad AVS check, make sure you're only
doing an auth -- B<not a sale>, or your customers would get charged on
orders that fail the AVS check and never get logged in your system!

Add the parameters like this:

    Route  merchantware  check_sub  mw_check

This is a matching sample subroutine you could put in interchange.cfg:

    GlobalSub <<EOR
    sub mw_check {
		my ($result, $transtype) = @_;
		my ($avs, $cvv) = @{$result}{qw( AvsResponse CvResponse )};
		return 1 unless $transtype eq 'auth';
#::logDebug("mw_check: transtype=$transtype; avs=$avs, cvv=$cvv");
		return 1 if $avs eq 'X' or $avs eq 'Y';   # address and zip match
		return 1 if $avs eq 'A' or $avs eq 'Z' or $avs eq 'W';   # address or zip match
		return 1 if $avs eq 'U' or $avs eq 'G';   # address info not available
		return 1 if $avs eq 'R' or $avs eq 'S';   # system unavailable, not supported
		return 1 if $avs =~ /^[BDMP]$/;           # intl match on address or postal
		## if we made it to this line, then the address is bad... (thus, we don't care about CVV if address is good)
		## below, we can accept if CVV is good, even if address is bad.
		return 1 if $cvv =~ /^[MPSUX]$/;   # accept all CVV responses, except no-match
		if ( !$cvv or $cvv eq 'N' ) {
			$result->{RESULT} = 99;
			$result->{ErrorMessage} = q{The card security code you entered does not match. Additional failed attempts may hold your available funds};
		}
		else {
			$result->{RESULT} = 112;
			$result->{ErrorMessage} = q{The billing address you entered does not match the cardholder's billing address};
		}
		$result->{MStatus} = 'failure';
		return 0;
    }
    EOR

That would work equally well as a Sub in catalog.cfg. It will succeed
if either the address or zip is 'Y', or if both are unknown. If it
fails, it sets the result code and error message in the result hash
using Merchantware's own (otherwise unused) 112 result code, meaning
C<Failed AVS check>.

Of course you can use this sub to do any other post-processing you
want as well.

=back

The following should rarely be used, as the supplied defaults are
usually correct.

=over 4

=item remap 

This remaps the form variable names to the ones needed by Merchantware. See
the C<Payment Settings> heading in the Interchange documentation for use.

=item test

Set this to C<TRUE> if you wish to operate in test mode.

Examples: 

    Route    merchantware  test  TRUE
        or
    Variable   MV_PAYMENT_TEST   TRUE
        or 
    [charge mode=merchantware test=TRUE]

=back

=head2 Troubleshooting

Try the instructions above, then enable test mode. A test order
should complete.

Then move to live mode and try a sale with the card number C<4111 1111
1111 1111> and a valid future expiration date. The sale should be denied,
and the reason should be in [data session payment_error].

If it doesn't work:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::Merchantware

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

If all else fails, consultants are available to help with
integration for a fee. You can find consultants by asking on the
C<interchange-biz@interchangecommerce.org> mailing list.

=back

=head1 TOKENS

MerchantWarehouse returns a token for each transaction. This is a
reference to the customer's credit card used in the original sale or
auth transaction, which you can use for future transactions against
that card.

For example, you can run a C<repeat_sale> using the token and expiration
date.

=over 4

You can also send the street address and ZIP for a C<repeat_sale>, so
MerchantWarehouse will run the AVS check. However, note that MW will not
decline a C<repeat_sale> if the AVS doesn't match -- this handling is
done via our check_sub. This is why the check_sub only fails on AVS
mismatch for C<auth> transactions. Thus, if you decide to fail a
C<repeat_sale> based on AVS mismatch, you will need to modify the
C<check_sub> to C<void> the C<repeat_sale>.

=back

Tokens are valid for 18 months. However, each transaction returns a new
token of its own, so if you update your system to replace your original
token with the one returned, you can effectively have a valid token for
the life of the credit card (or until the expiration date is reached).

=head1 REFERENCE

=head2 Transaction Types (not all supported or available)

	UNKNOWN	0	This value is reserved.
	SALE	1	A SALE charges an amount of money to a customer's credit card.
	REFUND	2	A REFUND credits an amount of money to a customer's credit card.
	VOID	3	A VOID removes a SALE, REFUND, FORCE, POSTAUTH, or ADJUST transaction from the current credit card processing batch.
	FORCE	4	A FORCE forces a charge on a customer's credit card. 
	AUTH	5	An AUTH reserves or holds an amount of money on a customer's credit card. 
	CAPTURE	6	A CAPTURE commits a single transaction as though it were batched. This feature is unsupported.
	ADJUST	7	An ADJUST is an adjustment on the amount of a prior sale or capture. Usually this is employed by businesses where tip-adjust on credit transactions are allowed.
	REPEATSALE	8	A REPEATSALE is a repeated sale of a prior sale transaction. Most accounts and merchants do not use this transaction type.
	POSTAUTH	9	A POSTAUTH completes the transaction process for a prior Authorization and allows it to enter the batch.
	LEVELUPSALE	11	A LEVELUPSALE charges an amount of money to a customer's LevelUp account.
	LEVELUPCREDIT	12	A LEVELUPCREDIT credits an amount of money to a customer's LevelUp account.

=head2 Response Values (Error Codes)

	-100	Transaction NOT Processed; Generic Host Error
	0	Approved
	1	User Authentication Failed
	2	Invalid Transaction
	3	Invalid Transaction Type
	4	Invalid Amount
	5	Invalid Merchant Information
	7	Field Format Error
	8	Not a Transaction Server
	9	Invalid Parameter Stream
	10	Too Many Line Items
	11	Client Timeout Waiting for Response
	12	Decline
	13	Referral
	14	Transaction Type Not Supported In This Version
	19	Original Transaction ID Not Found
	20	Customer Reference Number Not Found
	22	Invalid ABA Number
	23	Invalid Account Number
	24	Invalid Expiration Date
	25	Transaction Type Not Supported by Host
	26	Invalid Reference Number
	27	Invalid Receipt Information
	28	Invalid Check Holder Name
	29	Invalid Check Number
	30	Check DL Verification Requires DL State
	40	Transaction did not connect (to NCN because SecureNCIS is not running on the web server)
	50	Insufficient Funds Available
	99	General Error
	100	Invalid Transaction Returned from Host
	101	Timeout Value too Small or Invalid Time Out Value
	102	Processor Not Available
	103	Error Reading Response from Host
	104	Timeout waiting for Processor Response
	105	Credit Error
	106	Host Not Available
	107	Duplicate Suppression Timeout
	108	Void Error
	109	Timeout Waiting for Host Response
	110	Duplicate Transaction
	111	Capture Error
	112	Failed AVS Check
	113	Cannot Exceed Sales Cap
	1000	Generic Host Error
	1001	Invalid Login
	1002	Insufficient Privilege or Invalid Amount
	1003	Invalid Login Blocked
	1004	Invalid Login Deactivated
	1005	Transaction Type Not Allowed
	1006	Unsupported Processor
	1007	Invalid Request Message
	1008	Invalid Version
	1010	Payment Type Not Supported
	1011	Error Starting Transaction
	1012	Error Finishing Transaction
	1013	Error Checking Duplicate
	1014	No Records To Settle (in the current batch)
	1015	No Records To Process (in the current batch)

=head2 AVS Response Codes

	X	Exact: Address and nine-digit Zip match
	Y	Yes: Address and five-digit Zip match
	A	Address: Address matches, Zip does not
	Z	5-digit Zip: 5-digit Zip matches, address doesn't
	W	Whole Zip: 9-digit Zip matches, address doesn't
	N	No: Neither address nor Zip matches
	U	Unavailable: Address information not available
	G	Unavailable: Address information not available for international transaction
	R	Retry: System unavailable or time-out
	E	Error: Transaction unintelligible for AVS or edit error found in the message that prevents AVS from being performed
	S	Not Supported: Issuer doesn't support AVS service
	B	* Street Match: Street addresses match for international transaction, but postal code doesn't
	C	* Street Address: Street addresses and postal code not verified for international transaction
	D	* Match: Street addresses and postal codes match for international transaction
	I	* Not Verified: Address Information not verified for International transaction
	M	* Match: Street addresses and postal codes match for international transaction
	P	* Postal Match: Postal codes match for international transaction, but street address doesn't
	0	** No response sent
	5	Invalid AVS response

* These values are Visa specific.
** These values are returned by the Payment Server and not the processor. 

=head2 CVV Response Codes

	M	CVV2/CVC2/CID Match
	N	CVV2/CVC2/CID No Match
	P	Not Processed
	S	Issuer indicates that the CV data should be present on the card, but the merchant has indicated that the CV data is not present on the card.
	U	Unknown / Issuer has not certified for CV or issuer has not provided Visa/MasterCard with the CV encryption keys.
	X	Server Provider did not respond

=head1 NOTE

There is actually nothing in the package Vend::Payment::Merchantware. It
changes packages to Vend::Payment and places things there.

=head1 AUTHORS

Josh Lavin <josh@perusion.com>

=cut

BEGIN {
	eval {
		package Vend::Payment;
		require SOAP::Lite;
	};
    if ($@) {
        die "Required modules for Merchantware NOT found. $@\n";
    }

    ::logGlobal("%s payment module loaded",__PACKAGE__)
		unless $Vend::Quiet or ! $Global::VendRoot or ! $Global::VendRoot;
}

package Vend::Payment;

sub merchantware {
    my ($user, $amount) = @_;

    my ($opt, $secret, $partner);
    if (ref $user) {
        $opt = $user;
        $user = $opt->{id} || undef;
        $secret = $opt->{secret} || undef;
        $partner = $opt->{partner} || undef;
    }
    else {
        $opt = {};
    }

    my $actual;
    if ($opt->{actual}) {
        $actual = $opt->{actual};
    }
    else {
        my (%actual) = map_actual();
		$actual = \%actual;
    }
#::logDebug("actual map result: " . ::uneval($actual));

    if (! $user) {
        $user = charge_param('id')
            or return (
                MStatus => 'failure-hard',
                MErrMsg => errmsg('No account id'),
            );
    }
    if (! $secret) {
        $secret = charge_param('secret')
            or return (
                MStatus => 'failure-hard',
                MErrMsg => errmsg('No account password'),
            );
    }
    if (! $partner) {
        $partner = charge_param('partner')
            or return (
                MStatus => 'failure-hard',
                MErrMsg => errmsg('No account partner'),
            );
    }

	my @override = qw/
						order_id
						auth_code
						mv_credit_card_exp_month
						mv_credit_card_exp_year
						mv_credit_card_number
					/;
	for(@override) {
		next unless defined $opt->{$_};
		$actual->{$_} = $opt->{$_};
	}

    my $exp = sprintf(
				'%02d%02d',
				$actual->{mv_credit_card_exp_month},
				$actual->{mv_credit_card_exp_year},
			  );

	my $transtype = $opt->{transaction} || charge_param('transaction') || 'sale';

	my %type_map = (qw/
		authorize		auth
		settle_prior	settle
		refund			credit
		return			credit
		reverse			void
	/);

	if (defined $type_map{$transtype}) {
        $transtype = $type_map{$transtype};
    }

	my $order_id = gen_order_id($opt);

    my $precision = $opt->{precision} || charge_param('precision') || 2;

	$amount = $opt->{total_cost} if ! $amount;
	
    if (! $amount) {
        $amount = Vend::Interpolate::total_cost();
        $amount = Vend::Util::round_to_frac_digits($amount, $precision);
    }

    my $salestax = $opt->{salestax} || '';

    if (! $salestax) {
        $salestax = Vend::Interpolate::salestax();
        $salestax = Vend::Util::round_to_frac_digits($salestax, $precision);
    }

	if ($transtype eq 'void' and $order_id =~ /\w+$/) {
		$transtype = 'void_auth';
	}
#::logDebug("merchantware: transtype=$transtype, amount=$amount");

	# common query params:
    my %query = (
		merchantName			=> $partner,
		merchantSiteId			=> $user,
		merchantKey				=> $secret,
		invoiceNumber			=> $actual->{mv_order_number} || $actual->{mv_transaction_id},
		registerNumber			=> $Vend::Session->{ohost},
		merchantTransactionID	=> $order_id,
    );

## could also set forceDuplicate to 'true' (must be a string of 'true', apparently)

	my ($method, $token);
	if ( $actual->{auth_code} ) {
		$actual->{auth_code} =~ s/,(\w+)// and $token = $1;
	}

	if ( $transtype =~ /^(?:sale|auth|level2_sale)/ ) {
		my %addl = (
			amount				=> $amount,
			cardNumber			=> $actual->{mv_credit_card_number},
			expirationDate		=> $exp,
			cardholder			=> $actual->{b_name},
			avsStreetAddress	=> $actual->{b_address},
			avsStreetZipCode	=> $actual->{b_zip},
			cardSecurityCode	=> $actual->{mv_credit_card_cvv2},
		);
		while (my ($k,$v) = each %addl) {
			$query{$k} = $v;
		}
		$method = ($transtype eq 'sale') ? 'SaleKeyed' : 'PreAuthorizationKeyed';
	}
	elsif ($transtype eq 'credit') {
		$query{token}          = $token || $actual->{auth_code};
		$query{overrideAmount} = $amount;
		$method = 'Refund';
	}
	elsif ($transtype eq 'void') {
		$query{token} = $token || $actual->{auth_code};
		$method = 'Void';
	}
	elsif ($transtype eq 'settle') {
		$query{token}  = $token || $actual->{auth_code};
		$query{amount} = $amount;
		$method = 'PostAuthorization';
	}
	elsif ($transtype eq 'repeat_sale') {
		my %addl = (
			token => $token || $actual->{auth_code},
			overrideAmount   => $amount,
			expirationDate   => $exp,
			avsStreetAddress => $actual->{b_address},
			avsStreetZipCode => $actual->{b_zip},
		);
		while (my ($k,$v) = each %addl) {
			$query{$k} = $v;
		}
		$method = 'RepeatSale';
	}
	elsif ($transtype eq 'void_auth') {
		$query{token} = $token || $actual->{auth_code};
		$method = 'VoidPreAuthorization';
	}
	elsif ($transtype eq 'settle_batch') {
		$method = 'SettleBatch';
	}

	if ($transtype eq 'level2_sale') {
		$query{customerCode}  = $Vend::Session->{username} || $Vend::Session->{id};
		$query{poNumber}      = $actual->{po_number};
		$query{taxAmount}     = $salestax;
		$method = 'Level2SaleKeyed';
	}

# Uncomment all the following block to use the debug statement. It strips
# the arg of any sensitive credit card information and is safe
# to enable in production.
#{
#	my %munged_query = %query;
#	$munged_query{merchantKey} = 'XXXXXX';
#	$munged_query{cardNumber} =~ s/^(\d{4})(.*)/$1 . ('X' x length($2))/e;
#	$munged_query{cardSecurityCode} =~ s/./X/g;
#::logDebug("merchantware: method=$method");
#::logDebug("merchantware query: " . ::uneval(\%munged_query));
#}

	## Request.

    my $host = charge_param('test') ? 'staging.merchantware.net' : 'ps1.merchantware.net';

	my @parms;
	while (my ($k,$v) = each %query) {
		push @parms, SOAP::Data->name($k => $v);
	}
	my $soap = SOAP::Lite->new( proxy => "https://$host/Merchantware/ws/RetailTransaction/v4/Credit.asmx" );   # default timeout is 180 secs, from LWP::UserAgent
	$soap->default_ns('http://schemas.merchantwarehouse.com/merchantware/40/Credit/');
	$soap->on_action( sub { join '', @_ } );  # make it ok for .NET
	my $reply = $soap->call($method, @parms);

#::logDebug("merchantware result: $reply");
#::logDebug("merchantware: ".  uneval($reply) );

	my $result;
	if ( $reply->fault ) {
		return (
			RESULT  => -1,
			RESPMSG => 'System Error',
			MStatus => 'failure-hard',
			MErrMsg => 'System Error',
		);
	}
	else {
		$result = $reply->valueof('Body/' . $method . 'Response/' . $method . 'Result' );
	}

#::logDebug("merchantware result: ".  uneval($result) );

	my ($decline, $error_detail);

	if (
		$result->{ApprovalStatus} eq 'APPROVED'
			and
		my $check_sub_name = $opt->{check_sub} || charge_param('check_sub')
	) {
		my $check_sub = $Vend::Cfg->{Sub}{$check_sub_name} || $Global::GlobalSub->{$check_sub_name};
		if ( ref $check_sub eq 'CODE' ) {
			$decline = ! $check_sub->( $result, $transtype );
#::logDebug("merchantware check_sub: $check_sub_name, decline=$decline");
		}
		else {
			logError("merchantware: non-existent check_sub routine %s.", $check_sub_name);
		}
	}
	elsif ( $result->{ApprovalStatus} ne 'APPROVED' ) {
		$decline = 1;
		$error_detail = $result->{ApprovalStatus};
		$error_detail =~ s/\w+;//;
	}

	if ($decline) {
		$result->{MStatus} = 'failure';
		my $msg = $opt->{message_declined} ||
			errmsg(
				"Charge error: %s. Please call in your order or try again.", 
				$result->{ErrorMessage} || $error_detail || 'unknown error',
			);
		$result->{MErrMsg} = $msg;
	}
	else {
    	$result->{MStatus} = 'success';
		$result->{InvoiceNumber} ||= $order_id;
    }

    # IC names are on the left, Merchantware on the right
	my %result_map = (
		qw/
		  pop.status            ApprovalStatus
		  pop.error-message     ErrorMessage
		  order-id              InvoiceNumber
		  pop.order-id          InvoiceNumber
		  pop.auth-code         AuthorizationCode
		  pop.avs_code          AvsResponse
		  pop.cvv2_resp_code    CvResponse
		  /
	);

    for (keys %result_map) {
        $result->{$_} = $result->{$result_map{$_}}
            if defined $result->{$result_map{$_}};
    }
	$result->{'pop.auth-code'} .= ',' . $result->{Token};   # append token to auth-code. Is split out above for voids/captures/etc, as MW uses token, not auth-code.

#::logDebug('merchantware result: ' . ::uneval($result) );
    return %$result;
}

package Vend::Payment::Merchantware;

1;
