# Vend::Payment::PayflowPro - Interchange support for PayPal Payflow Pro HTTPS POST
#
# Copyright (C) 2002-2013 Interchange Development Group and others
# Copyright (C) 1999-2002 Red Hat, Inc.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

package Vend::Payment::PayflowPro;

=head1 NAME

Vend::Payment::PayflowPro - Interchange support for PayPal Payflow Pro HTTPS POST and PayPal Express Checkout

=head1 SYNOPSIS

    &charge=payflowpro

        or

    [charge mode=payflowpro param1=value1 param2=value2]

=head1 PREREQUISITES

    The following Perl modules:
       LWP
       Crypt::SSLeay
       HTTP::Request
       HTTP::Headers

    OpenSSL

PayPal's Payflow Pro HTTPS POST does NOT require the proprietary binary-only
shared library that was used for the Verisign Payflow Pro service.

=head1 DESCRIPTION

The Vend::Payment::PayflowPro module implements the payflowpro() payment routine
for use with Interchange.

It also allows you to accept PayPal via their Express Checkout (your
PayPal account must be linked to your PayPal Manager account to do so).

It is compatible on a call level with the other Interchange payment
modules -- in theory (and even usually in practice) you could switch
from a different payment module to PayflowPro with a few configuration
file changes.

To enable this module, place this directive in F<interchange.cfg>:

    Require module Vend::Payment::PayflowPro

This I<must> be in interchange.cfg or a file included from it.

NOTE: Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<payflowpro>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in F<catalog.cfg>:

    Variable  MV_PAYMENT_MODE  payflowpro

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable. For example, the C<id> parameter would
be specified by:

    [charge mode=payflowpro id=YourPayflowProID]

or

    Route payflowpro id YourPayflowProID

or with only Payflow Pro as a payment provider

    Variable MV_PAYMENT_ID YourPayflowProID

The active settings are:

=over 4

=item id

Your account ID, supplied by PayPal when you sign up.
Global parameter is MV_PAYMENT_ID.

=item secret

Your account password, selected by you or provided by PayPal when you sign up.
Global parameter is MV_PAYMENT_SECRET.

=item partner

Your account partner, selected by you or provided by PayPal when you
sign up. Global parameter is MV_PAYMENT_PARTNER.

=item vendor

Your account vendor, selected by you or provided by PayPal when you
sign up. Global parameter is MV_PAYMENT_VENDOR.

=item transaction

The type of transaction to be run. Valid values are:

    Interchange         Payflow Pro
    ----------------    -----------------
    sale                S
    auth                A
    credit              C
    void                V
    settle              D (from previous A trans)

Default is C<auth>.

=item accept_for_review

When using Fraud Protection Service, controls whether to accept orders
that triggered filters. Set to 1 to accept. You should also consider
changing the C<status> column of the transactions table to show that the
order was flagged. Something like this in F<etc/log_transaction>:

    status: [calc]return $Session->{payment_result}{RESULT} =~ /^12[67]$/ ? 'flagged' : 'pending';[/calc]

=item check_sub

Name of a Sub or GlobalSub to be called after the result hash has been
received from PayPal. A reference to the modifiable result hash is
passed into the subroutine, and it should return true (in the Perl truth
sense) if its checks were successful, or false if not. The transaction type
is passed in as a second arg, if needed.

This can come in handy since, strangely, PayPal has no option to decline
a charge when AVS or CSC data come back negative.

If you want to fail based on a bad AVS check, make sure you're only
doing an auth -- B<not a sale>, or your customers would get charged on
orders that fail the AVS check and never get logged in your system!

Add the parameters like this:

    Route  payflowpro  check_sub  avs_check

This is a matching sample subroutine you could put in interchange.cfg:

    GlobalSub <<EOR
    sub avs_check {
        my ($result) = @_;
        my ($addr, $zip) = @{$result}{qw( AVSADDR AVSZIP )};
        return 1 if $addr eq 'Y' or $zip eq 'Y';
        return 1 if $addr eq 'X' and $zip eq 'X';
        return 1 if $addr !~ /\S/ and $zip !~ /\S/;
        $result->{RESULT} = 112;
        $result->{RESPMSG} = "The billing address you entered does not match the cardholder's billing address";
        return 0;
    }
    EOR

That would work equally well as a Sub in catalog.cfg. It will succeed if
either the address or zip is 'Y', or if both are unknown. If it fails,
it sets the result code and error message in the result hash using
PayPal's own (otherwise unused) 112 result code, meaning C<Failed AVS
check>.

Of course you can use this sub to do any other post-processing you
want as well.

=back

B<The following are specific to PayPal Express Checkout:>

=over 4

=item returnurl

B<Required.> URL where the buyer will return to. Usually set to something like:

    __SECURE_SERVER____CGI_URL__/ord/paypalgetrequest

Create the page in F<pages/ord/paypalgetrequest.html> with contents of:

    [charge route="payflowpro" action="get"]
    [if value country eq GB]
        [value name=country set="UK" hide=1]
    [/if]
    [bounce href="[area href=ord/paypalcheckout]"]

also, set up F<pages/ord/paypalsetrequest.html>, with contents of:

    [charge route="payflowpro" action="set"]

    [if session paypal_token]
        [bounce href="https://www.[if variable INDEV]sandbox.[/if]paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=[data session paypal_token]"]
    [else]
        [bounce href="[area href=__CHECKOUT_PAGE__]"]
    [/else]
    [/if]

Then add the PayPal Checkout button to your basket page:

    <a href="[area ord/paypalsetrequest]"><img src="https://www.paypal.com/en_US/i/btn/btn_xpressCheckout.gif" alt="Checkout with PayPal"></a>

Add a F<pages/ord/paypalcheckout.html> page similar to your regular
checout page, but you may want to disable the editing of the address
fields. In addition, you should remove the
F<include/checkout/payment_method> and
F<include/checout/*_browser_payment> includes, and change the final
C<Place Order> button to include the order profile:

    [button 
        name="mv_click"
        text="[L]Place Order[/L]"
        wait-text="-- [L]Wait[/L] --"
        form=checkout
    ]
        mv_order_profile=paypal
        mv_todo=submit
    [/button]

In F<etc/log_transction>, immediately after the 
[elsif variable MV_PAYMENT_MODE]
line, look for the [charge] tag, and alter it to include the C<action>
parameter, like so:

    [charge route="[var MV_PAYMENT_MODE]" action="[if value mv_order_profile eq paypal]do[/if]" amount="...

Add into the end of the C<[import table=transactions type=LINE continue=NOTES no-commit=1]> section of F<etc/log_transaction>:

    pptransactionid: [calc]$Session->{payment_result}{TRANSACTIONID}[/calc]
    pppaymenttype: [calc]$Session->{payment_result}{PAYMENTTYPE}[/calc]
    pppendingreason: [calc]$Session->{payment_result}{PENDINGREASON}[/calc]
    ppcorrelationid: [calc]$Session->{payment_result}{CORRELATIONID}[/calc]
    pppayerstatus: [value pppayer_status]
    ppaddressstatus: [value ppaddress_status]

and add these 6 new columns into your transactions table as type
varchar(256). The CorrelationID is the one you need in any dispute with
them. The payerstatus and addressstatus results may be useful in the
order fulfillment process.

Add to F<etc/profiles.order>, something like:

    __NAME__                            paypal

    __COMMON_ORDER_PROFILE__
    email=required
    email=email
    &fatal = yes
    &setcheck = end_profile 1

    &set = mv_payment Incomplete

    [if variable MV_PAYMENT_MODE]
    [value name=mv_payment_realtime set=""]
    &set=mv_payment PayPal ([var MV_PAYMENT_MODE])
    &set=mv_payment_realtime 1
    [else]
    &set=mv_payment PayPal
    [/else]
    [/if]

    &final = yes
    &setcheck = end_profile 1
    &setcheck = payment_method paypal

    __END__

=item cancelurl

B<Required.> URL to go to if the buyer cancels. Usually set to your checkout page:

    __SECURE_SERVER____CGI_URL__/__CHECKOUT_PAGE__

=item headerimg

URL to your custom image to show the buyer during their PayPal.com session.

=item reqconfirmshipping

This specifies that a Paypal customer must have his address 'confirmed'

=item addressoverride

This specifies that you will ship only to the address IC has on file
(including the name and email); your customer needs to login to IC first
before going to Paypal

=item use_billing_override

Sends billing address instead of shipping to PayPal (use with
addressoverride)

=back

B<End PayPal>

The following should rarely be used, as the supplied defaults are
usually correct.

=over 4

=item remap

This remaps the form variable names to the ones needed by PayPal. See
the C<Payment Settings> heading in the Interchange documentation for use.

=item host

The payment gateway host to use, to override the default.

=back

=head2 Troubleshooting

Try the instructions above, then enable test mode. A test order should
complete.

Then move to live mode and try a sale with the card number C<4111 1111
1111 1111> and a valid future expiration date. The sale should be denied,
and the reason should be in [data session payment_error].

If it doesn't work:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::PayflowPro

=item *

Check the error logs, both catalog and global.

=item *

Make sure you set your account ID and secret properly.

=item *

Try an order, then put this code in a page:

    <pre>
    [calcn]
        my $string = $Tag->uneval( { ref => $Session->{payment_result} });
        $string =~ s/{/{\n/;
        $string =~ s/,/,\n/g;
        return $string;
    [/calcn]
    </pre>

That should show what happened.

=item *

If all else fails, consultants are available to help with
integration for a fee. You can find consultants by asking on the
C<interchange-biz@icdevgroup.org> mailing list.

=back

=head1 NOTE

See this URL for Payflow Pro documentation:
    https://developer.paypal.com/webapps/developer/docs/classic/payflow/gs_payflow/

See this URL for PayPal Express Checkout documentation:
    https://developer.paypal.com/webapps/developer/docs/classic/express-checkout/gs_expresscheckout/

There is actually nothing in the package Vend::Payment::PayflowPro.
It changes packages to Vend::Payment and places things there.

=head1 AUTHORS

    Josh Lavin <josh@perusion.com>
    Tom Tucker <tom@ttucker.com>
    Mark Johnson <mark@endpoint.com>
    Jordan Adler
    David Christensen <david@endpoint.com>
    Cameron Prince <cameronbprince@yahoo.com>
    Mike Heins <mike@perusion.com>
    Jon Jensen <jon@endpoint.com>

=cut

package Vend::Payment;

use Config;

BEGIN {
    eval {
        require LWP;
        require HTTP::Request;
        require HTTP::Headers;
        require Crypt::SSLeay;
    };
    if ($@) {
        die "Required modules for PayPal Payflow Pro HTTPS NOT found. $@\n";
    }
}

sub payflowpro {
    my ($user, $amount) = @_;
# Uncomment all the following lines to use the debug statement. It strips
# the arg of any sensitive credit card information and is safe
# (and recommended) to enable in production.
#
#    my $debug_user = ::uneval($user);
#    $debug_user =~ s{('mv_credit_card_[^']+' => ')((?:\\'|\\|[^\\']*)*)(')}{$1 . ('X' x length($2)) . $3}ge;
#::logDebug("payflowpro called\n" . $debug_user);

    my ($opt, $secret);
    if (ref $user) {
        $opt = $user;
        $user = $opt->{id} || undef;
        $secret = $opt->{secret} || undef;
    }
    else {
        $opt = {};
    }
    my %actual;
    if ($opt->{actual}) {
        %actual = %{$opt->{actual}};
    }
    else {
        %actual = map_actual();
    }

    if (! $user) {
        $user = charge_param('id')
            or return (
                MStatus => 'failure-hard',
                MErrMsg => errmsg('No account id'),
            );
    }
#::logDebug("payflowpro user $user");

    if (! $secret) {
        $secret = charge_param('secret')
            or return (
                MStatus => 'failure-hard',
                MErrMsg => errmsg('No account password'),
            );
    }

    my $accept_for_review = $opt->{accept_for_review} || charge_param('accept_for_review');

#::logDebug("payflowpro OrderID: |$opt->{order_id}|");

    my ($server, $port);
    if (! $opt->{host} and charge_param('test')) {
#::logDebug("payflowpro: setting server to pilot/test mode");
        $server = 'pilot-payflowpro.paypal.com';
        $port = '443';
    }
    else {
#::logDebug("payflowpro: setting server based on options");
        $server = $opt->{host} || 'payflowpro.paypal.com';
        $port = $opt->{port} || '443';
    }

    my $uri = "https://$server:$port/transaction";
#::logDebug("payflowpro: using uri: $uri");

    $actual{mv_credit_card_exp_month} =~ s/\D//g;
    $actual{mv_credit_card_exp_month} =~ s/^0+//;
    $actual{mv_credit_card_exp_year}  =~ s/\D//g;
    $actual{mv_credit_card_exp_year}  =~ s/\d\d(\d\d)/$1/;
    $actual{mv_credit_card_number}    =~ s/\D//g;

    my $exp = sprintf '%02d%02d',
        $actual{mv_credit_card_exp_month},
        $actual{mv_credit_card_exp_year};

    my %type_map = (qw/
        sale          S
        auth          A
        authorize     A
        void          V
        settle        D
        settle_prior  D
        credit        C
        mauthcapture  S
        mauthonly     A
        mauthdelay    D
        mauthreturn   C
        S             S
        C             C
        D             D
        V             V
        A             A
    /);

    my $transtype = $opt->{transaction} || charge_param('transaction') || 'A';

    $transtype = $type_map{$transtype}
        or return (
                MStatus => 'failure-hard',
                MErrMsg => errmsg('Unrecognized transaction: %s', $transtype),
            );

    my $order_id = gen_order_id($opt);

    my $precision = $opt->{precision} || charge_param('precision') || 2;

    $amount = $opt->{total_cost} if ! $amount;

    if (! $amount) {
        $amount = Vend::Interpolate::total_cost();
        $amount = Vend::Util::round_to_frac_digits($amount, $precision);
    }

    my $shipping = $opt->{shipping} || '';

    if (! $shipping) {
        $shipping = Vend::Interpolate::tag_shipping();
        $shipping = Vend::Util::round_to_frac_digits($shipping, $precision);
    }

    my $salestax = $opt->{salestax} || '';

    if (! $salestax) {
        $salestax = Vend::Interpolate::salestax();
        $salestax = Vend::Util::round_to_frac_digits($salestax, $precision);
    }

    my $subtotal = $opt->{subtotal} || '';

    if (! $subtotal) {
        $subtotal = Vend::Interpolate::subtotal();
        $subtotal = Vend::Util::round_to_frac_digits($subtotal, $precision);
    }

    my $phone = $actual{phone_day} || $actual{phone_night};
    $phone =~ s/\D//g;

    my %varmap = (qw/
        ACCT             mv_credit_card_number
        CVV2             mv_credit_card_cvv2
        BILLTOFIRSTNAME  b_fname
        BILLTOLASTNAME   b_lname
        BILLTOSTREET     b_address
        BILLTOCITY       b_city
        BILLTOSTATE      b_state
        BILLTOZIP        b_zip
        SHIPTOFIRSTNAME  fname
        SHIPTOLASTNAME   lname
        SHIPTOSTREET     address
        SHIPTOCITY       city
        SHIPTOSTATE      state
        SHIPTOZIP        zip
        BILLTOEMAIL      email
        EMAIL            email
        COMMENT1         comment1
        COMMENT2         comment2
    /);

    my $action = $opt->{action};
    $action =~ s/set/S/;
    $action =~ s/get/G/;
    $action =~ s/do/D/;

    my $tender;
    $tender = $action ? 'P' : 'C';   # tender must be P for PayPal

    my $tdb = dbref('transactions') or die errmsg("cannot open transactions table");
    my $existing_trans = $tdb->foreign($order_id, 'order_id');  # lookup order_id in transactions, to see what payment_method was.
    if($existing_trans) {
        my $pay_method = $tdb->field($existing_trans, 'payment_method');
        $tender = 'P' if $pay_method =~ /^PayPal/i;
    }

    my %query = (
        AMT            => $amount,
        CURRENCY       => 'USD',
        TENDER         => $tender,
        PWD            => $secret,
        USER           => $user,
        TRXTYPE        => $transtype,
        CUSTIP         => $Vend::Session->{ohost},
        TAXAMT         => $salestax,
        TAXEXEMPT      => ($salestax > 0) ? 'N' : 'Y',
        FREIGHTAMT     => $shipping,
        BILLTOPHONENUM => $phone,
        BILLTOCOUNTRY  => ($actual{b_country} eq 'UK') ? 'GB' : $actual{b_country},
        SHIPTOCOUNTRY  => ($actual{country} eq 'UK') ? 'GB' : $actual{country},
    );
    my %paypal_query = (
        ACTION               => $action,
        RETURNURL            => charge_param('returnurl'),
        CANCELURL            => charge_param('cancelurl'),
        TOKEN                => ($action eq 'S' ? '' : $Vend::Session->{paypal_token}),
        ALLOWNOTE            => charge_param('allow_note'),
        REQBILLINGADDRESS    => charge_param('reqbillingaddress'),
        REQCONFIRMSHIPPING   => charge_param('reqconfirmshipping'),
        PAGESTYLE            => charge_param('pagestyle'),
        HDRIMG               => charge_param('headerimg'),
        HDRBORDERCOLOR       => charge_param('headerbordercolor'),
        HDRBACKCOLOR         => charge_param('headerbackcolor'),
        PAYFLOWCOLOR         => charge_param('payflowcolor'),
        ITEMAMT              => $subtotal,
        PAYERID              => $CGI::values{payerid} || $::Values->{pppayerid},
        NOTETOBUYER          => charge_param('note_to_buyer') || '*** Discounts and coupons will be shown and applied before final payment',
        PAYMENTREQUEST_0_AMT => $amount,
    );
    if($tender eq 'P') {
        @query{keys %paypal_query} = values %paypal_query;
        my $i = 0;
        for my $it (@{$::Carts->{main}}) {
            $query{'L_PAYMENTREQUEST_0_NAME'    .$i} = $it->{description} || Vend::Data::item_description($it);
            $query{'L_PAYMENTREQUEST_0_NUMBER'  .$i} = $it->{code};
            $query{'L_PAYMENTREQUEST_0_DESC'    .$i} = Vend::Data::item_description($it);
            $query{'L_PAYMENTREQUEST_0_AMT'     .$i} = Vend::Data::item_price($it);
            $query{'L_PAYMENTREQUEST_0_QTY'     .$i} = $it->{quantity};
            ##$query{'L_PAYMENTREQUEST_0_TAXAMT'.$i} = (Vend::Data::item_price($it)/$itemTotal * $taxTotal);
            $i++;
        }
        $opt->{check_sub} = undef;
    }
    else {
        my $i = 1;
        for my $it (@{$::Carts->{main}}) {
            $query{'L_NAME' . $i} = $it->{description} || Vend::Data::item_description($it);
            $query{'L_COST' . $i} = Vend::Data::item_price($it);
            $query{'L_QTY'  . $i} = $it->{quantity};
            $query{'L_SKU'  . $i} = $it->{code};
            ##$query{'L_TAXAMT'.$i} = (Vend::Data::item_price($it)/$itemTotal * $taxTotal);
            $i++;
        }
    }

    $query{PARTNER}  = $opt->{partner} || charge_param('partner');
    $query{VENDOR}   = $opt->{vendor}  || charge_param('vendor');
    $query{COMMENT1} = $order_id if ! $actual{comment1};

    if($action =~ /[SG]/) {
        ## if a PayPal set/get, don't want address, just email.
        $query{EMAIL} = $actual{$varmap{EMAIL}} if defined $actual{$varmap{EMAIL}};
    }
    elsif($action eq 'D') {
        ## don't want some.
        delete $query{ACCT};
        delete $query{CVV2};
        for (keys %varmap) {
            $query{$_} = $actual{$varmap{$_}} if defined $actual{$varmap{$_}};
        }
    }
    else {
        ## these not for PayPal authorizations, only capture/void (and credit cards):
        $query{ORIGID} = $order_id;
        $query{EXPDATE} = $exp;
        for (keys %varmap) {
            $query{$_} = $actual{$varmap{$_}} if defined $actual{$varmap{$_}};
        }
    }

# Uncomment all the following block to use the debug statement. It strips
# the arg of any sensitive credit card information and is safe
# (and recommended) to enable in production.
#
#    {
#        my %munged_query = %query;
#        $munged_query{PWD} = 'X';
#        $munged_query{ACCT} =~ s/^(\d{4})(.*)/$1 . ('X' x length($2))/e;
#        $munged_query{CVV2} =~ s/./X/g;
#        $munged_query{EXPDATE} =~ s/./X/g;
#::logDebug("payflowpro query: " . ::uneval(\%munged_query));
#    }

    my $timeout = $opt->{timeout} || 45;
    die "Bad timeout value, security violation." unless $timeout && $timeout !~ /\D/;
    die "Bad port value, security violation." unless $port && $port !~ /\D/;
    die "Bad server value, security violation." unless $server && $server !~ /[^-\w.]/;

    my $result = {};

    my (@query, @debug_query);
    for my $key (keys %query) {
        my $val = $query{$key};
        $val =~ s/["\$\n\r]//g;
        my $len = length($val);
        $key .= "[$len]";
        push @query, "$key=$val";
        $val =~ s/./X/g
            if $key =~ /^(?:PWD|ACCT|CVV2|EXPDATE)\b/;
        push @debug_query, "$key=$val";
    }
    my $string = join '&', @query;
    my $debug_string = join '&', @debug_query;

	my $reqid = $transtype =~ /^[DVC]$/ ? ($order_id . int(rand(100))) : $order_id;
#::logDebug("payflowpro using X-VPS-Request-Id = $reqid");

    my %headers = (
        'Content-Type'                    => 'text/namevalue',
        'X-VPS-Request-Id'                => $reqid,
        'X-VPS-Timeout'                   => $timeout,
        'X-VPS-VIT-Client-Architecture'   => $Config{archname},
        'X-VPS-VIT-Client-Type'           => 'Perl',
        'X-VPS-VIT-Client-Version'        => $VERSION,
        'X-VPS-VIT-Integration-Product'   => 'Interchange',
        'X-VPS-VIT-Integration-Version'   => $::VERSION,
        'X-VPS-VIT-OS-Name'               => $Config{osname},
        'X-VPS-VIT-OS-Version'            => $Config{osvers},
        'PAYPAL-NVP'                      => ($tender eq 'P' ? 'Y' : ''),
    );
# Debug statement is stripped of any sensitive card data and is safe (and
# recommended) to enable in production.
#
#::logDebug(qq{--------------------\nPosting to PayflowPro: \n\t$order_id\n\t$uri "$debug_string"});

    my $headers = HTTP::Headers->new(%headers);
    my $request = HTTP::Request->new('POST', $uri, $headers, $string);
    my $ua = LWP::UserAgent->new(timeout => $timeout);
    $ua->agent('Vend::Payment::PayflowPro');
    my $response = $ua->request($request);
    my $resultstr = $response->content;
#::logDebug(qq{PayflowPro response:\n\t$resultstr\n--------------------});

    unless ( $response->is_success ) {
        return (
            RESULT => -1,
            RESPMSG => 'System Error',
            MStatus => 'failure-hard',
            MErrMsg => 'System Error',
            lwp_response => $resultstr,
        );
    }

    %$result = split /[&=]/, $resultstr;
    if($tender eq 'P') {
        for(keys %$result) {
            my $v = delete $result->{$_};
            $_ =~ s|\[\d+\]$||;   # remove length tags for NVP
            $_ =~ s|^PAYMENTINFO_0_||;  # also strip 'paymentinfo_0'
            $result->{$_} = $v;
        }
    }

    my $decline = $result->{RESULT};

    if (
        $result->{RESULT} =~ /^0|12[67]$/
            and
        my $check_sub_name = $opt->{check_sub} || charge_param('check_sub')
    ) {
        my $check_sub = $Vend::Cfg->{Sub}{$check_sub_name}
            || $Global::GlobalSub->{$check_sub_name};
        if (ref $check_sub eq 'CODE') {
            $decline =
                !$check_sub->(
                    $result,
                    $transtype,
                );
#::logDebug(qq{payflowpro called check_sub sub=$check_sub_name decline=$decline});
        }
        else {
            logError("payflowpro: non-existent check_sub routine %s.", $check_sub_name);
        }
    }

    my %result_map = (qw/
        MStatus        ICSTATUS
        pop.status     ICSTATUS
        order-id       PNREF
        pop.order-id   PNREF
        pop.auth-code  AUTHCODE
        pop.avs_code   AVSZIP
        pop.avs_zip    AVSZIP
        pop.avs_addr   AVSADDR
    /);

    if ($accept_for_review and $decline =~ /^12[67]$/) {   ## flagged for review, or not screened by filters
        $result->{ICSTATUS} = 'success';
    }
    elsif ($decline) {
        $result->{ICSTATUS} = 'failed';
        my $msg = errmsg("Charge error: %s Reason: %s. Please call in your order or try again.",
            $result->{RESULT} || 'no details available',
            $result->{RESPMSG} || 'unknown error',
        );
        $result->{MErrMsg} = $result{'pop.error-message'} = $msg;
    }
    else {
        $result->{ICSTATUS} = 'success';
        if($result->{TOKEN}) {
            ## PayPal transaction.
            $Vend::Session->{paypal_token} = $result->{TOKEN};
            if($action eq 'G') {
                ## save address details in Values...
                my %val_map = (qw/
                    email             EMAIL
                    pppayerid         PAYERID
                    pppayer_status    PAYERSTATUS
                    gift_note         NOTE
                    fname             FIRSTNAME
                    lname             LASTNAME
                    address1          SHIPTOSTREET
                    address2          SHIPTOSTREET2
                    city              SHIPTOCITY
                    state             SHIPTOSTATE
                    zip               SHIPTOZIP
                    country           SHIPTOCOUNTRY
                    company           SHIPTOBUSINESS
                    phone_day         PHONENUM
                    b_address1        STREET
                    b_address2        STREET2
                    b_city            CITY
                    b_state           STATE
                    b_zip             ZIP
                    b_country         COUNTRYCODE
                    ppaddress_status  ADDRESSSTATUS
                /);
                for (keys %val_map) {
                    $::Values->{$_} = $result->{$val_map{$_}}
                        if defined $result->{$val_map{$_}};
                }
            }
        }
    }

    for (keys %result_map) {
        $result->{$_} = $result->{$result_map{$_}}
            if defined $result->{$result_map{$_}};
    }

#::logDebug('payflowpro result: ' . ::uneval($result));
    return %$result;
}

package Vend::Payment::PayflowPro;

1;
