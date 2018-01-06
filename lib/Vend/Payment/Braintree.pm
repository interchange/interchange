package Vend::Payment::Braintree;

=head1 NAME

Vend::Payment::Braintree - Interchange Braintree support

=head1 SYNOPSIS

    &charge=braintree
 
        or
 
    [charge mode=braintree param1=value1 param2=value2]

=head1 PREREQUISITES

  Net::Braintree

=head1 DESCRIPTION

The Vend::Payment::Braintree module implements the braintree() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::Braintree

This I<must> be in interchange.cfg or a file included from it.

The mode can be named anything, but the C<gateway> parameter must be set to
C<braintree>. To make it the default payment gateway for all credit card
transactions in a specific catalog, based on demo catalog settings, you can
set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  braintree

It uses several of the standard settings from Interchange payment. Those with
an asterisk are required. The active settings are:

=over 4

=item merchant_id*

Supplied from Braintree

=item public_key*

Supplied from Braintree

=item private_key*

Supplied from Braintree

=item environment*

One of B<sandbox>, B<integration>, B<development>, B<qa>, or B<production>.
Use C<production> for live transaction processing, and C<sandbox> for testing
and development.

=item transaction

As Braintree is the PayPal successor to Payflow Pro, the transaction
identifiers were patterned off of PFP's. The traditional Interchange
identifiers for transactions are also supported:

    Interchange         Braintree
    ----------------    -----------------
        auth            A
        return          C
        sale            S
        settle          D
        void            V

Default transaction is C<A>.

There are additional Braintree transactions specific to the particular gateway's API:

=over 4

=item mini_auth, M

Use when a validation authorization is desired. The C<M> transaction will return
any authorization error that may occur on the card along with AVS and CVC
validation.

The transaction ID in response to a C<M> is a C<payment_method_token>. This
will have to be used for subsequent transaction activity as the Braintree
nonce can only be used once. This is the scalar response from $Tag->charge or
the value found in [data session payment_id].

=item find, F

Use to find the current details of a transaction in Braintree. Particularly
useful for issuing refunds where, depending on status, Braintree requires
either voiding the authorization or running a credit against the settlement.

=item client_token, T

Server-side interface for generating and returning the client token needed by
front-end integration for interacting with Braintree. Token is returned as the
transaction ID, i.e., scalar response from $Tag->charge or value found in
[data session payment_id].

=back

=item payment_method_nonce

Token supplied from Braintree frontend integration that references a specific
payment instrument. The nonce is only capable of a single use. To acquire a
permanent token to the payment instrument, issue a C<M> transaction and store
the resulting transaction ID for use as a C<payment_method_token>

=item payment_method_token

Permanent token from Braintree vault for accessing the associated payment
instrument. If both a C<payment_method_nonce> and C<payment_method_token> are
present in the request, the token is preferred.

=item comment1

For compatibility with PFP for passing in the Interchange order number, or
other local order identifier, to Braintree to pair with the transactions.

=item order_id

Transaction ID for follow-on transaction. E.g., transaction ID from an
authorization to submit a capture request.

=item check_sub

Name of a global or catalog subroutine to post-process the raw result from the transaction type as received from Net::Braintree.

Subroutine is provided 2 arguments:

=over 4

=item $result

Hash reference to the full return structure from Net::Braintree. The structure
will depend on which transaction type was run and the result of the
transaction. So dissecting the first argument will require examining the arg
structure itself, Net::Braintree code, and Braintree documentation.

=item $transaction

Canonical transaction type identifer. Will be one of C<A>, C<C>, C<D>, C<F>,
C<M>, C<S>, C<T>, or C<V>.

=back

Subroutine should return perly true or false, to indiciate if the result of
the transaction should be processed as success or failure.

=item test

Does not support a test identifier like most Interchange payment modules.
Control whether running tests or live transactions by the C<environment>
setting.

=back

=head2 Fraud detection parameters

There are a number of settings associated with additional Braintree services
for fraud detection. Currently implemented:

=over 4

=item *
custom_fields

=item *
device_data

=item *
merchant_account_id

=item *
skip_advanced_fraud_checking

=back

Fraud results, when present, will be found in the RISK_DATA key of the results
hash.

See Braintree documentation for details on fraud-detection services.

=head2 Credit card data

Braintree shields sensitive card-holder data from the merchant to avoid higher
levels of PCI burden.  However, that necessarily means the usual payment
information is unavailable from any user-submitted forms as is typical for
Interchange implementations.

The card-holder data Braintree does make available after transaction
processing can be found in the CARD_DATA key of the results hash. The hash can
be accessed like a standard hash or, because it's a Hash::Inflator object, can
have its keys accessed via method calls.

A typical CARD_DATA hash might look like:

 'CARD_DATA' => {
   'bin' => '411111',
   'card_type' => 'Visa',
   'cardholder_name' => 'Gimmy Giblets',
   'commercial' => 'Unknown',
   'country_of_issuance' => 'USA',
   'customer_location' => 'US',
   'debit' => 'Yes',
   'durbin_regulated' => 'Yes',
   'expiration_month' => '08',
   'expiration_year' => '2021',
   'healthcare' => 'No',
   'issuing_bank' => 'Bank of America, National Association',
   'last_4' => '1111',
   'payroll' => 'No',
   'prepaid' => 'No',
   'product_id' => 'F',
   'token' => 'foobar',
   'unique_number_identifier' => 'xxxxxxxxxx80f47de7486c7809ea21e0'
 },

The exact composition will depend on a number of factors determined by
Braintree and the specific payment instrument. But the most important
keys--those identifying bin, last 4, cardtype, expiration--should always be
present.

=head2 Troubleshooting

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::Braintree

=item *

Make sure Net::Braintree is installed and working. You can test to see whether
your Perl thinks it is:

    perl -MNet::Braintree -e 'print "$Net::Braintree::VERSION\n"'

If that prints a version number, then the module is installed with the version noted.

=item *

Check the error logs, both catalog and global.

=item *

Make sure you set your required payment parameters properly.

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
See http://www.icdevgroup.org/ for mailing lists and other information.

=back

=head1 AUTHORS

    Mark Johnson <mark@endpoint.com>
    Jon Jensen <jon@endpoint.com>

=cut

use strict;
use warnings;

BEGIN {
    require Net::Braintree;

    # Redefining the refund() routine here because it is broken
    # in Net::Braintree::Transaction. Without the override, you cannot
    # submit additional parameters Braintree suppports.
    #
    # The CPAN modules are no longer actively maintained and a patch
    # to fix this issue was rejected. To make handling Braintree as
    # simple as possible in Interchange, this local override allows
    # a direct CPAN install of Net::Braintree to fully function.

    no warnings 'redefine';
    *Net::Braintree::Transaction::refund = sub {
        # Follow-on credit
        my ($class, $id, $amount) = @_;
        my $params;
        if (ref $amount) {
            $params = $amount;
        }
        else {
            $params = {};
            $params->{'amount'} = $amount if $amount;
        }
        $class->gateway->transaction->refund($id, $params);
    };
}

::logGlobal('%s module loaded', __PACKAGE__);

*charge_param = \&Vend::Payment::charge_param;

sub get_token {
    my $route = shift || charge_param('mode');
    my $opt;
    if (ref ($route) ) {
        $opt = $route;
    }
    elsif ( not defined($route) && length($route)) {
        ::logError(__PACKAGE__ . "::get_token requires a route hash or name");
        return;
    }
    else {
        $opt = $Vend::Cfg->{Route_repository}{$route};
    }
    my $config = Net::Braintree->configuration;
    $config->$_($opt->{$_}) for qw( environment merchant_id public_key private_key );
    return Net::Braintree::ClientToken->generate;
}

sub response_map {
    return qw/
        order-id       PNREF
        pop.order-id   PNREF
        pop.auth-code  AUTHCODE
        pop.avs_code   AVSZIP
        pop.avs_zip    AVSZIP
        pop.avs_addr   AVSADDR
    /;
}

sub method_map {
    local $_ = shift;

    return 'create' if /M/;
    return 'sale' if /S|A/;
    return 'submit_for_settlement' if /D/;
    return 'void' if /V/;
    return 'refund' if /C/;
    return 'find' if /F/;

    die "'$_' is an invalid transaction type";
}

sub scrub_addresses {
    my $opt = shift;

    for (qw( country b_country )) {
        $opt->{$_} = 'GB' if $opt->{$_} eq 'UK';
    }

    # Braintree says postal codes must be no more than 9 alphanumeric characters, with spaces and hyphens ignored
    # https://developers.braintreepayments.com/reference/request/address/create/ruby#postal_code
    for (qw( zip b_zip )) {
        $opt->{$_} =~ s/[^A-Za-z0-9]+//g;
        $opt->{$_} = substr($opt->{$_}, 0, 9);
    }

    return;
}

sub handle_avs {
    my $E = shift;

    return ('','') if $E;

    my @rv;

    for (@_) {
        my $v = /M/ ? 'Y' : /N/ ? 'N' : /[UI]/ ? 'X' : '';
        push @rv, $v;
    }

    return @rv;
}

sub gateway_rejection_reason_code {
    my $reason = shift;
    # These negative number codes are our arbitrary invention to include gateway rejections in the same result code.
    # See https://developers.braintreepayments.com/reference/response/credit-card-verification/ruby#gateway_rejection_reason
    my %map = (
        avs                    => -101,
        avs_and_cvv            => -102,
        cvv                    => -103,
        duplicate              => -104,
        fraud                  => -105,
        three_d_secure         => -106,
        application_incomplete => -107,
    );
    return $map{$reason} || -100;
}

sub client_token {
    my ($transtype, $amount, $opt) = @_;
    my $result;
    {
        local $@;
        $result =
            eval {
                no warnings 'redefine';
                local *Carp::longmess = \&Carp::shortmess
                    if $opt->{environment} eq 'production';
                get_token($opt);
            }
            or do {
                my $err = ::errmsg('Unable to retrieve client token: %s', $@ || 'no information from eval block.');
                ::logError($err);
                return (
                    MStatus => 'failure-hard',
                    MErrMsg => $err,
                );
            }
        ;
    }

    return (
        MStatus => 'success',
        'order-id' => $result,
    );
}

sub transaction {
    my ($transtype, $amount, $opt) = @_;

    my $method = method_map($transtype);

    my @args;

    if ($transtype =~ /[SA]/) {
        my ($k, $v);
        for (grep { $opt->{$_} } qw/payment_method_token payment_method_nonce/) {
            $k = $_;
            $v = $opt->{$_};
            last;
        }

        $v or return (
            MStatus => 'failure-hard',
            MErrMsg => ::errmsg('No nonce or token present to process %s type transaction', $transtype),
        );

        my %act = %{ $opt->{actual} };
        scrub_addresses(\%act);

        my %params = (
            amount => $amount,
            $k => $v,
            options => {},
            shipping => {
                first_name => $act{fname},
                last_name => $act{lname},
                street_address => $act{address1},
                extended_address => $act{address2},
                locality => $act{city},
                region => $act{state},
                postal_code => $act{zip},
                country_code_alpha2 => $act{country},
            },
        );

        for (grep { $opt->{$_} } qw/custom_fields device_data merchant_account_id/) {
            $params{$_} = $opt->{$_};
        }

        for (grep { defined $opt->{$_} } qw/skip_advanced_fraud_checking/) {
            $params{options}{$_} = $opt->{$_};
        }

        # if $k is a nonce, then we're not using a previously defined
        # customer. So supply user's billing information and email
        if ($k eq 'payment_method_nonce') {
            $params{billing} = {
                first_name => $act{b_fname},
                last_name => $act{b_lname},
                street_address => $act{b_address1},
                extended_address => $act{b_address2},
                locality => $act{b_city},
                region => $act{b_state},
                postal_code => $act{b_zip},
                country_code_alpha2 => $act{b_country},
            };
            $params{customer} = {
                first_name => $act{b_fname},
                last_name => $act{b_lname},
                email => $act{email},
                phone => $act{b_phone} || $act{phone} || $act{phone_day} || $act{phone_night},
            };
        }

        $params{options}{submit_for_settlement} = $transtype =~ /S/ ? 1 : 0;
        $params{order_id} = $opt->{comment1}
            if $opt->{comment1};

        push (@args, \%params);
    }
    else {
        push (@args, $opt->{order_id});
        push (@args, $amount)
            unless $transtype =~ /[VF]/;
    }

    my $gwl = Vend::Payment::Braintree::GWL
        -> new({
            Enabled => charge_param('gwl_enabled'),
            LogTable => charge_param('gwl_table'),
            Source => charge_param('gwl_source'),
        })
    ;
    $gwl->request({
        opt => {
            %$opt,
            transtype => $transtype,
        },
        args => $gwl->label_args(\@args),
    });
#::logDebug("calling braintree's %s transaction method with args %s\n", $method, ::uneval(\@args));
    my $result;
    {
        local $@;
        $result =
            eval {
                no warnings 'redefine';
                local *Carp::longmess = \&Carp::shortmess
                    if $opt->{environment} eq 'production';

                my $config = Net::Braintree->configuration;
                $config->$_($opt->{$_})
                    for qw/environment merchant_id public_key private_key/;

                $gwl->start;
                Net::Braintree::Transaction->$method(@args);
            }
            or do {
                my $err = $@ || "Net::Braintree::Transaction returned no object but did not die for $method call";
                $gwl->stop;
                $gwl->response({ return => {}, eval_error => $err, },);
                return (
                    MStatus => 'failure-hard',
                    MErrMsg => ::errmsg('Unable to contact payment processor. Please try again.'),
                );
            }
        ;
        $gwl->stop;
        $gwl->response({ return => { RESPMSG => 'N/A'}, raw => $result, });
    }
#::logDebug("braintree transaction $method result: " . ::uneval($result));

    my ($success, $api_err, $t);

    unless ($api_err = $result->api_error_response) {
        $t = $result->transaction;
        $success = $result->is_success
            && defined($t)
            && $t->processor_response_code =~ /^1\d{3}$/;
    }

    if (
        $success
            and
        my $check_sub_name = $opt->{check_sub} || charge_param('check_sub')
    ) {
        my $check_sub = $Vend::Cfg->{Sub}{$check_sub_name}
            || $Global::GlobalSub->{$check_sub_name};
        if (ref $check_sub eq 'CODE') {
            $success =
                $check_sub->(
                    $result,
                    $transtype,
                )
            ;
        }
    }

    my %response;

    if ($api_err) {
        my ($msg, $code);
        if (exists $api_err->{transaction}) {
            my $et = $api_err->{transaction};
            $msg  = $et->{processor_response_text};
            $code = $et->{processor_response_code};
        }
        if (exists $api_err->{errors}{transaction}{errors}) {
            my $arr = $api_err->{errors}{transaction}{errors};
            if (ref($arr) eq 'ARRAY' and @$arr) {
                my $e = $arr->[0];
                $msg  = $e->{message};
                $code = $e->{code};
            }
        }
        %response = (
            RESPMSG => $msg || $api_err->{message} || 'Unknown',
            RESULT => $code || -1,
        );
    }
    elsif ($t) {
        %response = (
            PNREF => $t->id,
            RESPMSG => $t->processor_response_text || $result->message || 'Unknown',
            RESULT => $t->processor_response_code || -1,
            STATUS => $t->status,
        );

        $response{AUTHCODE} = $t->processor_authorization_code
            if $t->processor_authorization_code;

        @response{qw/AVSADDR AVSZIP/} =
            handle_avs(
                $t->avs_error_response_code,
                $t->avs_street_address_response_code,
                $t->avs_postal_code_response_code,
            )
        ;

        {
            local $_ = $t->cvv_response_code;
            $response{CVV2MATCH} = /M/ ? 'Y' : /N/ ? 'N' : /[UI]/ ? 'X' : '';
        }

        $response{CARD_DATA} = $t->credit_card_details
            if $t->credit_card_details;

        eval {
            $response{RISK_DATA} = $response{risk_data} = $t->risk_data
                if $t->risk_data;
        };
    }
    else {
        %response = (
            RESPMSG => $result->{message} || 'Unknown',
            RESULT => -1,
        );
    }

    $response{MStatus} = $success ? 'success' : 'failed';
    $response{MErrMsg} = $response{RESPMSG} if !$success;

    my %response_map = response_map();
    for (keys %response_map) {
        $response{$_} = $response{$response_map{$_}}
            if defined $response{$response_map{$_}};
    }
#::logDebug("braintree transaction $method response: " . ::uneval(\%response));

    $gwl->response({ return => \%response, raw => $result, });
    return %response;
}

sub customer {
    my ($transtype, $amount, $opt) = @_;

    my $method = method_map($transtype);

    $opt->{payment_method_nonce}
        or return (
            MStatus => 'failure-hard',
            MErrMsg => ::errmsg('Nonce missing; unable to process %s type transaction', $transtype),
        )
    ;

    my %act = %{ $opt->{actual} };
    scrub_addresses(\%act);

    my %params = (
        first_name => $act{b_fname},
        last_name => $act{b_lname},
        email => $act{email},
        phone => $act{b_phone} || $act{phone} || $act{phone_day} || $act{phone_night},
        credit_card => {
            payment_method_nonce => $opt->{payment_method_nonce},
            cardholder_name => "$act{b_fname} $act{b_lname}",
            billing_address => {
                first_name => $act{b_fname},
                last_name => $act{b_lname},
                street_address => $act{b_address1},
                extended_address => $act{b_address2},
                locality => $act{b_city},
                region => $act{b_state},
                postal_code => $act{b_zip},
                country_code_alpha2 => $act{b_country},
            },
            options => {
                verify_card => 1,
            },
        },
    );

    $params{credit_card}{options}{verification_merchant_account_id} = $opt->{merchant_account_id}
        if $opt->{merchant_account_id};

    for (grep { $opt->{$_} } qw/custom_fields device_data/) {
        $params{$_} = $opt->{$_};
    }

    my @args = (\%params);
    my $gwl = Vend::Payment::Braintree::GWL
        -> new({
            Enabled => charge_param('gwl_enabled'),
            LogTable => charge_param('gwl_table'),
            Source => charge_param('gwl_source'),
        })
    ;
    $gwl->request({
        opt => {
            %$opt,
            transtype => $transtype,
        },
        args => $gwl->label_args(\@args),
    });
#::logDebug("calling braintree's %s customer method with args %s\n", $method, ::uneval(\@args));
    my $result;
    {
        local $@;
        $result =
            eval {
                no warnings 'redefine';
                local *Carp::longmess = \&Carp::shortmess
                    if $opt->{environment} eq 'production';

                my $config = Net::Braintree->configuration;
                $config->$_($opt->{$_})
                    for qw/environment merchant_id public_key private_key/;

                $gwl->start;
                Net::Braintree::Customer->$method(@args);
            }
            or do {
                my $err = $@ || "Net::Braintree::Customer returned no object but did not die for $method call";
                $gwl->stop;
                $gwl->response({ return => {}, eval_error => $err, },);
                return (
                    MStatus => 'failure-hard',
                    MErrMsg => ::errmsg('Unable to contact payment processor. Please try again.'),
                );
            }
        ;
        $gwl->stop;
        $gwl->response({ return => { RESPMSG => 'N/A'}, raw => $result, });
    }
#::logDebug("braintree customer $method result: " . ::uneval($result));

    my ($success, $api_err, $c, $pm, $ver);

    unless ($api_err = $result->api_error_response) {
        $c = $result->customer;
        $pm = $c && $c->payment_methods->[0];
        $ver = $pm && $pm->verifications->[0];

        $success = $result->is_success
            && defined($ver)
            && $ver->processor_response_code =~ /^1\d{3}$/;
    }

    if (
        $success
            and
        my $check_sub_name = $opt->{check_sub} || charge_param('check_sub')
    ) {
        my $check_sub = $Vend::Cfg->{Sub}{$check_sub_name}
            || $Global::GlobalSub->{$check_sub_name};
        if (ref $check_sub eq 'CODE') {
            $success =
                $check_sub->(
                    $result,
                    $transtype,
                )
            ;
        }
    }

    my %response;

    if ($api_err) {
        my ($msg, $code);
        if (exists $api_err->{verification}) {
            my $ev = $api_err->{verification};
            if ($ev->{gateway_rejection_reason}) {
                # "If a transaction was authorized before being rejected, the gateway will automatically void it."
                # https://articles.braintreepayments.com/control-panel/transactions/gateway-rejections
                $msg = $api_err->{message};
                $code = gateway_rejection_reason_code($ev->{gateway_rejection_reason});
            }
            else {
                $msg  = $ev->{processor_response_text};
                $code = $ev->{processor_response_code};
            }
        }
        if (exists $api_err->{errors}{customer}{credit_card}{errors}) {
            my $arr = $api_err->{errors}{customer}{credit_card}{errors};
            if (ref($arr) eq 'ARRAY' and @$arr) {
                my $e = $arr->[0];
                $msg  = $e->{message};
                $code = $e->{code};
            }
        }
        if (exists $api_err->{errors}{customer}{credit_card}{billing_address}{errors}) {
            my $arr = $api_err->{errors}{customer}{credit_card}{billing_address}{errors};
            if (ref($arr) eq 'ARRAY' and @$arr) {
                my $e = $arr->[0];
                $msg  = $e->{message};
                $code = $e->{code};
            }
        }
        %response = (
            RESPMSG => $msg || $api_err->{message} || 'Unknown',
            RESULT => $code || -1,
        );
    }
    elsif ($ver) {
        %response = (
            PNREF => $pm->token,
            RESPMSG => $ver->processor_response_text || $result->message || 'Unknown',
            RESULT => $ver->processor_response_code || -1,
            CUSTOMER_ID => $c->id,
        );

        @response{qw/AVSADDR AVSZIP/} =
            handle_avs(
                $ver->avs_error_response_code,
                $ver->avs_street_address_response_code,
                $ver->avs_postal_code_response_code,
            )
        ;

        {
            local $_ = $ver->cvv_response_code;
            $response{CVV2MATCH} = /M/ ? 'Y' : /N/ ? 'N' : /[UI]/ ? 'X' : '';
        }

        $response{CARD_DATA} = $ver->credit_card
            if $ver->credit_card;

        eval {
            $response{RISK_DATA} = $response{risk_data} = $ver->risk_data
                if $ver->risk_data;
        };
    }
    else {
        %response = (
            RESPMSG => $result->{message} || 'Unknown',
            RESULT => -1,
        );
    }

    $response{MStatus} = $success ? 'success' : 'failed';
    $response{MErrMsg} = $response{RESPMSG} if !$success;

    my %response_map = response_map();
    for (keys %response_map) {
        $response{$_} = $response{$response_map{$_}}
            if defined $response{$response_map{$_}};
    }
#::logDebug("braintree customer $method response: " . ::uneval(\%response));

    $gwl->response({ return => \%response, raw => $result, });
    return %response;
}

package Vend::Payment;

use strict;
use warnings;

sub braintree {
    my ($user, $amount) = @_;

#::logDebug("braintree called\n%s\n", ::uneval($user));

    my $opt;
    if(ref $user) {
        $opt = $user;
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
    # This quirk is for ensuring access to actual in subprocessing routines
    $opt->{actual} ||= $actual;

    my %type_map = qw/
        sale          S
        auth          A
        authorize     A
        void          V
        settle        D
        settle_prior  D
        credit        C
        mini_auth     M
        verify        M
        status        F
        find          F
        client_token  T
        token         T
        T             T
        F             F
        S             S
        C             C
        D             D
        V             V
        A             A
        M             M
    /;

    my $transtype = $opt->{transaction} || charge_param('transaction') || 'A';

    $transtype = $type_map{$transtype}
        or return (
                MStatus => 'failure-hard',
                MErrMsg => ::errmsg('Unrecognized transaction: %s', $transtype),
            );

    $amount = $opt->{total_cost} if ! $amount;

    if (! $amount) {
        my $precision = $opt->{precision} || charge_param('precision') || 2;
        my $cost = Vend::Interpolate::total_cost();
        $amount = Vend::Util::round_to_frac_digits($cost, $precision);
    }

    my $sub =
        $transtype eq 'M' ? \&Vend::Payment::Braintree::customer     :
        $transtype eq 'T' ? \&Vend::Payment::Braintree::client_token :
                            \&Vend::Payment::Braintree::transaction
    ;

    return $sub->($transtype, $amount, $opt);
}

package Vend::Payment::Braintree::GWL;

use base qw/Vend::Payment::GatewayLog/;
use Scalar::Util qw/reftype/;

# Return structure from Net::Braintree is exceptionally bloated. The response
# is passed through a number of thinning processes to make it much more
# readable and take considerably less storage space.

# Constants to define arrays of typically bloating, useless keys per
# transaction/reftype combination. They will be culled if they are present but
# undefined; otherwise, they will persist into gateway_log table.

use constant CUSTOMER_HASH_KEYS =>
[qw/
    customer
/];

use constant CUSTOMER_ARRAY_KEYS =>
[qw/
    refund_ids
/];

use constant CUSTOMER_SCALAR_KEYS =>
[qw/
    company
    fax
    refund_id
    refunded_transaction_id
    website
/];

use constant CUSTOMER_CC_KEYS =>
[qw/
    subscriptions
/];

use constant TRANSACTION_HASH_KEYS =>
[qw/
    descriptor
    disbursement_details
    processor_settlement_response_code
    processor_settlement_response_text
    subscription
/];

use constant TRANSACTION_ARRAY_KEYS =>
[qw/
    add_ons
    discounts
    disputes
    partial_settlement_transaction_ids
/];

use constant TRANSACTION_SCALAR_KEYS =>
[qw/
    additional_processor_response
    authorized_transaction_id
    channel
    escrow_status
    master_merchant_account_id
    plan_id
    purchase_order_number
    service_fee_amount
    settlement_batch_id
    sub_merchant_account_id
    subscription_id
    three_d_secure_info
    voice_referral_number
/];

# Remove certain completely empty response objects corresponding to KEYS
# definitions above.

sub thin_hashes {
    # hashes either empty or with all undef values
    my ($obj, $prefix, $fields) = @_;
    for my $k (@$fields) {
        next unless exists $obj->{$k};
        my $h = $obj->{$k};
        if (grep { defined($h->{$_}) } keys %$h) {
            ::logError("Unexpected defined value found in $prefix$k - preserving entire hash\n");
        }
        else {
            delete $obj->{$k};
        }
    }
    return;
}

sub thin_arrays {
    # empty arrays
    my ($obj, $prefix, $fields) = @_;
    for my $k (@$fields) {
        next unless exists $obj->{$k};
        my $arr = $obj->{$k};
        if (ref($arr) ne 'ARRAY' or @$arr) {
            ::logError("Unexpected data type or array not empty in $prefix$k - preserving\n");
        }
        else {
            delete $obj->{$k};
        }
    }
    return;
}

sub thin_scalars {
    # undef scalars
    my ($obj, $prefix, $fields) = @_;
    for my $k (@$fields) {
        next unless exists $obj->{$k};
        if (defined $obj->{$k}) {
            ::logError("Unexpected defined value in $prefix$k - preserving\n");
        }
        else {
            delete $obj->{$k};
        }
    }
    return;
}

# Stringify timestamps for readability and bloat reduction

sub thin_datetimes {
    # stringify DateTime objects directly on source reference
    my $ref = shift;

    my $type = ref ($$ref)
        or return;

    if ( $type eq 'DateTime' ) {
        $$ref = $$ref->formatter->format_datetime($$ref);
        return;
    }

    my $rtype = reftype($$ref);
    if ( $rtype eq 'HASH' ) {
        thin_datetimes(\$_) for values %$$ref;
    }
    elsif ( $rtype eq 'ARRAY' ) {
        thin_datetimes(\$_) for @$$ref;
    }

    return;
}

# Deflate all hashes

sub hash_deflate {
    # convert any hash objects into regular hashes
    my $ref = shift;

    my $rtype = reftype($$ref)
        or return;

    my $type = ref ($$ref);

    if ($rtype eq 'HASH') {

        hash_deflate(\$_) for values %$$ref;

        if ($type ne $rtype) {
            $$ref = { %$$ref };
        }
    }
    elsif ($rtype eq 'ARRAY') {

        hash_deflate(\$_) for @$$ref;

    }

    return;
}

# Main routine to act on the top-level response object. Delegates to the above
# routines.

sub thin_response_object {
    my $orig = shift;
    return $orig unless $orig and reftype($orig) eq 'HASH';

    # Deep copy the object contents so we don't affect the original
    my $obj = eval ::uneval($orig);

    # Scrub all annoying DateTime objects
    thin_datetimes(\$obj);

    # Deflate all remaining hash objects
    hash_deflate(\$obj);

    delete $obj->{return}{CARD_DATA}{image_url}
        if exists $obj->{return}{CARD_DATA};

    return $obj unless exists $obj->{raw} and reftype($obj->{raw}) eq 'HASH';

    if (exists $orig->{raw}{response}{customer}) {
        my $customer = $obj->{raw}{response}{customer};
        my $prefix = 'raw.response.customer.';
        thin_hashes( $customer, $prefix, CUSTOMER_HASH_KEYS);
        thin_arrays( $customer, $prefix, CUSTOMER_ARRAY_KEYS);
        thin_scalars($customer, $prefix, CUSTOMER_SCALAR_KEYS);
        my $cc_n = 0;
        for my $cc (@{ $customer->{credit_cards} }) {
            my $cc_prefix = $prefix . "credit_cards.$cc_n.";
            ++$cc_n;
            thin_arrays($cc, $cc_prefix, CUSTOMER_CC_KEYS);
            delete $cc->{image_url};
        }
    }

    if (exists $orig->{raw}{response}{transaction}) {
        my $txn = $obj->{raw}{response}{transaction};
        my $prefix = 'raw.response.trasaction.';
        thin_hashes( $txn, $prefix, TRANSACTION_HASH_KEYS);
        thin_arrays( $txn, $prefix, TRANSACTION_ARRAY_KEYS);
        thin_scalars($txn, $prefix, TRANSACTION_SCALAR_KEYS);
        delete $txn->{credit_card}{image_url};
    }

    return $obj;
}

# log_it() must be overridden.
sub log_it {
    my $self = shift;

    my $request = $self->request;
    unless ($request) {
        ::logDebug('Cannot write to %s: no request present', $self->table);
        return;
    }

    unless ($self->response) {
        if ($Vend::Payment::Global_Timeout) {
            my $msg = errmsg('No response. Global timeout triggered');
            ::logDebug($msg);
            $self->response({
                return => {
                    RESULT => -2,
                    RESPMSG => $Vend::Payment::Global_Timeout,
                },
            });
        }
        else {
            my $msg = errmsg('No response. Reason unknown');
            ::logDebug($msg);
            $self->response({
                return => {
                    RESULT => -3,
                    RESPMSG => $msg,
                },
            });
        }
    }

    my $response = $self->response;

    my $return = $response->{return};
    my $rc =
        defined ($return->{RESULT})
        && $return->{RESULT} =~ /^-?\d+$/
            ? $return->{RESULT}
            : undef
    ;

    my $opt = delete $request->{opt};
    my $processor = $opt->{route} || $opt->{gateway};

    my $thinned_response = eval {
        thin_response_object($response)
    };
    if ($@ or !$thinned_response) {
        ::logError("Error thinning Braintree response" . ($@ ? ": $@" : ''));
        $thinned_response = $response;
    }
#::logDebug("Gateway log thinned response: " . ::uneval($thinned_response));

    my %fields = (
        trans_type => $opt->{transtype} || 'x',
        processor => $processor || 'braintree',
        catalog => $Vend::Cfg->{CatalogName},
        result_code => $rc || '',
        response_msg => $return->{RESPMSG} || '',
        request_id => $return->{PNREF} || '',
        order_number => $opt->{comment1} || '',
        request_duration => $self->duration,
        request_date => $self->timestamp,
        request_source => $self->source,
        email => $opt->{actual}{email} || '',
        request => ::uneval($request) || '',
        response => ::uneval($thinned_response) || '',
        session_id => $::Session->{id} || '',
        amount => $request->{args}{AMT} || $request->{args}{amount} || '',
        host_ip => $::Session->{shost} || $::Session->{ohost} || '',
        username => $::Session->{username} || '',
        cart_md5 => '',
    );

    if (@$Vend::Items) {
        my $dump = Data::Dumper
            -> new($Vend::Items)
            -> Indent(0)
            -> Terse(1)
            -> Deepcopy(1)
            -> Sortkeys(1)
        ;
        $fields{cart_md5} = Digest::MD5::md5_hex($dump->Dump);
    }

    $self->write(\%fields);
}

sub label_args {
    my $self = shift;
    my $orig = shift;

    return 'malformed request argument list' unless
        reftype ($orig) eq 'ARRAY'
        &&
        scalar @$orig
    ;

    # Ensure manipulations of argument ref are insulated
    my $arg = eval ::uneval($orig);

    return $arg->[0] if ref($arg->[0]) and reftype($arg->[0]) eq 'HASH';

    my @k = qw/ORIGID AMT/;
    my %hsh;

    while (@$arg && @k) {
        $hsh{ shift (@k) } = shift @$arg;
    }

    if (@$arg) {
        $hsh{unknown} = $arg;
    }

    return \%hsh;
}

1;
