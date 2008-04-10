# Vend::Payment::Protx2 - Interchange Protx Direct payment support
#
# $Id: Protx2.pm,v 1.2 2008-04-10 23:44:45 jon Exp $
# Based on Protx2.pm, v 2.1.2, July 2007
#
# Copyright (C) 2008 Interchange Development Group
# Copyright (C) 2007 Zolotek Resources Ltd. All rights reserved.
#
# Author: Lyn St George <info@zolotek.net, http://www.zolotek.net>
# Based on original code by Mike Heins <mheins@perusion.com> and others.
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public Licence as published by
# the Free Software Foundation; either version 2 of the Licence, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public Licence for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

package Vend::Payment::Protx2;

=head1 NAME

Interchange Protx Direct payment system interface

=head1 PREREQUISITES

Net::SSLeay
    or
LWP::UserAgent and Crypt::SSLeay

wget - a recent version built with SSL and supporting the 'connect' timeout function.

=head1 QUICK START SUMMARY

1. Call this module in interchange.cfg with:

    Require module Vend::Payment::Protx2

2. Add into products/variable.txt (tab separated):

    MV_PAYMENT_MODE   protx

3. Add a new route into catalog.cfg (options for the last entry in parentheses):

    Route protx id YourProtxID
    Route protx host ukvps.protx.com (ukvpstest.protx.com)
    Route protx currency GBP (USD, EUR, others, defaults to GBP)
    Route protx txtype PAYMENT (AUTHENTICATE, DEFERRED)
    Route protx available yes (no, empty)
    Route protx logzero yes (no, empty)
    Route protx double_pay yes (no, empty)
    Route protx logdir "path/to/log/dir"
    Route protx protxlog yes (no, empty)
    Route protx applyavscv2 '0': if enabled then check, and if rules apply use.
                            '1': force checks even if not enabled; if rules apply use.
                            '2': force NO checks even if enabled on account.
                            '3': force checks even if not enabled; do NOT apply rules.
    Route protx giftaidpayment 0 (1 to donate tax to Gift Aid)

or put these vars into products/variable.txt instead:

    MV_PAYMENT_ID   YourProtxID Payment
    MV_PAYMENT_MODE protx   Payment
    MV_PAYMENT_HOST ukvps.protx.com Payment
    MV_PAYMENT_CURRENCY GBP Payment

and the rest as above.

4. Create a new locale setting for en_UK as noted in "item currency" below, and copy the
public space interchange/en_US/ directory to a new interchange/en_UK/ one. Ensure that any
other locales you might use have a correctly named directory as well. Ensure that this locale
is found in your version of locale.txt (and set up UK as opposed to US language strings to taste).

5. Create entry boxes on your checkout page for: 'mv_credit_card_issue_number', 'mv_credit_card_start_month',
'mv_credit_card_start_year', 'mv_credit_card_type', and optionally 'mv_credit_card_cvv2'.

=head1 DESCRIPTION

The Vend::Payment::Protx module implements the Protx() routine for use with
Interchange. It is not compatible on a call level with the other Interchange
payment modules - Protx does things rather differently. We need to save four of
the returned codes for re-use when doing a RELEASE, REPEAT, or REFUND.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::Protx2

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

Note that the Protx 'Direct' system is the only one which leaves the customer on
your own site and takes payment in real time. Their other systems, eg Terminal
or Server, do not require this module.

Note also that Maestro cards can only be taken by the 3DSecure version of this module, not by this
version, as Mastercard have decreed that Maestro cards will no longer be accepted without 3DSecure.

While PREAUTH is still in this module, it is scheduled to be dropped on the 1st August 2007 or shortly
thereafter, and is only here as a backup during the changeover to AUTHENTICATE.

=head2 The active settings

The module uses several of the standard settings from the Interchange payment routes.
Any such setting, as a general rule, is obtained first from the tag/call options on
a page, then from an Interchange order Route named for the mode in catalog.cfg,
then a default global payment variable in products/variable.txt, and finally in
some cases a default will be hard-coded into the module.

=over

=item Mode

The mode can be named anything, but the C<gateway> parameter must be set
to C<protx>. To make it the default payment gateway for all credit card
transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable  MV_PAYMENT_MODE  protx

or in variable.txt:

    MV_PAYMENT_MODE protx (tab separated)

if you want this to cooperate with other payment systems, eg PaypalExpress or GoogleCheckout, then see
the documentation that comes with that system - it should be fully explained there (essentially, you
don't run the charge route from profiles.order but from log_transaction).

=item id

Your Protx vendor ID, supplied by Protx when you sign up. Various ways to state this:

in variable.txt:

    MV_PAYMENT_ID   YourProtxID Payment

or in catalog.cfg either of:

    Route protx id YourProtxID
    Variable MV_PAYMENT_ID      YourProtxID

=item txtype

The transaction type is one of: PAYMENT, AUTHENTICATE or DEFERRED for an initial purchase
through the catalogue, and then can be one of: REFUND, RELEASE, REPEAT for payment
operations through the virtual terminal.

The transaction type is taken firstly from a dynamic variable in the page, meant
primarily for use with the 'virtual payment terminal', viz: 'transtype' in a select box
though this could usefully be taken from a possible entry in the products database
if you have different products to be sold on different terms; then falling back to
a 'Route txtype AUTHENTICATE' entry in catalog.cfg; then falling back to a global
variable in variable.txt, eg 'MV_PAYMENT_TXTYPE AUTHENTICATE Payment'; and finally
defaulting to 'PAYMENT' hard-coded into the module. This variable is returned to
the module and logged using the value returned from Protx, rather than a value from
the page which possibly may not exist.

=item available

If 'yes', then the module will check that the gateway is responding before sending the transaction.
If it fails to respond within 9 seconds, then the module will go 'off line' and log the transaction
as though this module had not been called. It will also log the txtype as 'OFFLINE' so that you
know you have to put the transaction through manually later (you will need to capture the card
number to do this). The point of this is that your customer has the transaction done and dusted,
rather than being told to 'try again later' and leaving for ever. If not explicitly 'yes',
defaults to 'no'. NB: if you set this to 'yes', then add into the etc/report that is sent to you:
Txtype = [calc]($Session->{payment_result} || {})->{TxType};[/calc]. Note that you need to have
a recent version of wget which supports '--connect-timeout' to run this check. Note also that,
as this transaction has not been logged anywhere on the Protx server, you cannot use their
terminal to process it. You must use the PTIPM which includes a function for this purpose; ie,
it updates the existing order number with the new payment information returned from Protx. Note
further that if you have Protx set up to require the CV2 value, then the PTIPM will disable
CV2 checking at run-time by default for such a transaction (logging the CV2 value breaks Visa/MC
rules and so it can't be legally available for this process).

=item logzero

If 'yes', then the module will log a transaction even if the amount sent is zero (which the
gateway would normally reject). The point of this is to allow a zero amount in the middle of a
subscription billing series for audit purposes. If not explicitly 'yes', defaults to 'no'.
Note: this is only useful if you are using an invoicing system or the Payment Terminal, both of which
by-pass the normal IC processes. IC will allow an item to be processed at zero total price but simply
bypasses the gateway when doing so.

=item logempty

If 'yes, then if the response from Protx is read as empty (ie, zero bytes) the result is forced to
'success' and the transaction logged as though the customer has paid. There are two markers set to
warn of this:

$Session->{payment_result}{TxType} will be NULL,

$Session->{payment_result}{StatusDetail} will be: 'UNKNOWN status - check with Protx before dispatching goods'

and you should include these into the report emailed to you.

=item card_type

Protx requires that the card type be sent. Valid types are: VISA, MC, AMEX, DELTA, SOLO, UKE,
JCB, DINERS (UKE is Visa Electron issued in the UK). MAESTRO is no longer accepted without 3DSecure.
This may optionally be determined by the module using regexes, or you may use a select box on the page.
If there is an error in the regex match in this module due to a change in card ranges or some other
fault, then Protx will refuse the transaction and return an error message to the page. Using a select
box on the page automatically overrides use of the internal option. In the interests of robust
reliability it is *strongly* recommended that you use a select box.

You may display a select box on the checkout page like so:

    <select name="mv_credit_card_type">
    [loop
        option=mv_credit_card_type
        acclist=1
        list=|
            VISA=Visa,
            MC=MasterCard,
            SOLO=Solo,
            DELTA=Delta,
            AMEX=Amex,
            UKE=Electron,
            JCB=JCB,
            DINERS=Diners
        |
    ]
        <option value="[loop-code]">[loop-param label]</option>
    [/loop]
    </select>

=item currency

Protx requires that a currency code be sent, using the 3 letter ISO standard,
eg, GBP, EUR, USD. The value is taken firstly from either a page setting or a
possible value in the products database, viz 'iso_currency_code'; then falling back
to the locale setting - for this you need to add to locale.txt:

    code    en_UK   en_EUR  en_US
    iso_currency_code   GBP EUR USD

It then falls back to a 'Route protx currency EUR' type entry in catalog.cfg;
then falls back to a global variable (eg MV_PAYMENT_CURRENCY EUR Payment); and
finally defaults to GBP hard-coded into the module. This variable is returned to
the module and logged using the value returned from Protx, rather than a value from
the page which possibly may not exist.

=item cvv2

This is sent to Protx as mv_credit_card_cvv2. Put this on the checkout page:

    CVV2: <input type=text name=mv_credit_card_cvv2 value='' size=6>

but note that under PCI rules you must not log this value anywhere.

=item issue_number

This is used for some debit cards, and taken from an input box on the checkout page:

    Card issue number: <input type=text name=mv_credit_card_issue_number value='' size=6>

=item StartDate

This is used for some debit cards, and is taken from select boxes on the
checkout page in a similar style to those for the card expiry date. The labels to be
used are: 'mv_credit_card_start_month', 'mv_credit_card_start_year'. Eg:

    <select name="mv_credit_card_start_year">
    [loop option=start_date_year lr=1 list=`
        my $year = $Tag->time( '', { format => '%Y' }, '%Y' );
        my $out = '';
        for ($year - 7 .. $year) {
                /\d\d(\d\d)/;
                $last_two = $1;
                $out .= "$last_two\t$_\n";
        }
        return $out;
    `]
        <option value="[loop-code]">[loop-pos 1]</option>
    [/loop]
    </select>

=item Log directory

To choose the directory used for logging both the Protx latency log and the double
payment safeguard record, set in catalog.cfg:

    Route protx logdir "path/to/log/dir"

It must be relative to the catalog root directory if you have
NoAbsolute set for this catalog in interchange.cfg.

If logdir is not set, it defaults to the system /tmp.

A somewhat dangerous option allows the payment page to specify the
logdir in a form variable, like this:

    <input type="hidden" name="logdir" value='your_choice_here'>

This allows an individual user to have his own logs in a shared hosting
environment. However, it also allows a creative end-user to create
arbitrary empty files or update timestamps of existing files.

Because of the potential for abuse, this option is not allowed unless you set
a special route variable indicating you want it:

    Route protx logdir_from_user_allowed 1

=item Protx API v2.22 extra functions

ApplyAVSCV2 set to:

    0 = If AVS/CV2 enabled then check them. If rules apply, use rules. (default)
    1 = Force AVS/CV2 checks even if not enabled for the account. If rules apply, use rules.
    2 = Force NO AVS/CV2 checks even if enabled on account.
    3 = Force AVS/CV2 checks even if not enabled for the account but DON'T apply any rules.
    You may pass this value from the page as 'applyavscv2' to override the payment route setting.

CustomerName: optional, may be different to the cardholder name

ContactFax: optional

GiftAidPayment: set to -
    0 = This transaction is not a Gift Aid charitable donation(default)
    1 = This payment is a Gift Aid charitable donation and the customer has AGREED to donate the tax.
    You may pass this value from the page as 'giftaidpayment'

ClientIPAddress: will show in Protx reports, and they will attempt to Geo-locate the IP.

=item Encrypted email with card info

If you want to add the extra fields (issue no, start date) to the PGP message
emailed back to you, then set the following in catalog.cfg:

    Variable<tab>MV_CREDIT_CARD_INFO_TEMPLATE Card type: {MV_CREDIT_CARD_TYPE}; Card no: {MV_CREDIT_CARD_NUMBER}; Expiry: {MV_CREDIT_CARD_EXP_MONTH}/{MV_CREDIT_CARD_EXP_YEAR}; Issue no: {MV_CREDIT_CARD_ISSUE_NUMBER}; StartDate: {MV_CREDIT_CARD_START_MONTH}/{MV_CREDIT_CARD_START_YEAR}

=item testing

The Protx test site is ukvpstest.protx.com, and their live site is
ukvps.protx.com. Enable one of these in MV_PAYMENT_HOST in variable.txt
(*without* any leading https://) or as 'Route protx host ukvpstest.protx.com' in
catalog.cfg.

=item methods

NB: Protx have removed PREAUTH from their protocol and replaced it with AUTHENTICATE/AUTHORISE.

An AUTHENTICATE will validate the card and store the card details on Protx's system for up to 90 days.
Against this you may AUTHORISE for any amount up to 115% of the original value.

A DEFERRED will place a shadow ('block') on the funds for seven days (or so, depending
on the acquiring bank). Against a DEFERRED you may do a RELEASE to settle the transaction.

A PAYMENT will take the funds immediately. Against a PAYMENT, you may do a
REFUND or REPEAT.

A RELEASE is performed to settle a DEFERRED. Payment of the originally specified
amount is guaranteed if the RELEASE is performed within the seven days for which
the card-holder's funds are 'blocked'.

A REFUND may be performed against a PAYMENT, RELEASE, AUTHORISE or REPEAT. It may be for a
partial amount or the entire amount, and may be repeated with several partial
REFUNDs so long as the total does not exceed the original amount.

A DIRECTREFUND sends funds from your registered bank account to the nominated credit card.
This does not need to refer to any previous transaction codes, and is useful if you need to
make a refund but the customer's card has changed or the original purchase was not made by card.

=back

=head2 Virtual Payment Terminal

This has now been split out from this module, and may be found as the rather pretentiously named
Payment Terminal Interchange Plug-in Module (PTIPM), also on http://kiwi.zolotek.net. The PTIPM
does refunds and repeats, directrefunds, and converts offline transactions to online ones. Being a
plugin to the Interchange Admin Panel it integrates these operations into your database.

=head1 TROUBLESHOOTING

Only the test card numbers given below will be successfully
authorised (all other card numbers will be declined).

    VISA                    4929 0000 0000 6
    MASTERCARD              5404 0000 0000 0001
    DELTA                   4462000000000003
    SOLO                    6334900000000005      issue 1
    DOMESTIC MAESTRO        5641 8200 0000 0005   issue 01 (should be rejected now)
    AMEX                    3742 0000 0000 004
    ELECTRON                4917 3000 0000 0008
    JCB                     3569 9900 0000 0009
    DINERS                  3600 0000 0000 08

You'll also need to supply the following values for CV2, Billing Address Numbers and Billing Post Code
Numbers. These are the only values which will return as Matched on the test server. Any other values
will return a Not Matched on the test server.

    CV2                        123
    Billing Address Numbers    88
    Billing Post Code Numbers  412

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::Protx2

=item *

Make sure either Net::SSLeay or Crypt::SSLeay and LWP::UserAgent are installed
and working. You can test to see whether your Perl thinks they are:

    perl -MNet::SSLeay -e 'print "It works\n"'
or
    perl -MLWP::UserAgent -MCrypt::SSLeay -e 'print "It works\n"'

If either one prints "It works." and returns to the prompt you should be OK
(presuming they are in working order otherwise).

=item *

Check the error logs, both catalogue and global. Make sure you set your payment
parameters properly. Try an order, then put this code in a page:

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

If you have unexplained and unlogged errors then check you have allowed the new database fields to
be NULL. If MySQL tries to write to a field that is marked NOT NULL then it will fail silently.

=item *

If you have a PGP/GPG failure when placing an order through your catalogue
then this may cause the module to be immediately re-run. As the first run would
have been successful, meaning that both the basket and the credit card information
would have been emptied, the second run will fail. The likely error message within
the catalogue will be:
"Can't figure out credit card expiration". Fixing PGP/GPG will fix this error.

If you get the same error message within the Virtual Terminal, then you haven't
set the order route as noted above.

=item *

If all else fails, Zolotek and other consultants are available to help
with integration for a fee.

=back

=head1 RESOURCES

http://kiwi.zolotek.net is the home page with the latest version. Also to be found on
Kevin Walsh's excellent Interchange site, http://interchange.rtfm.info.

=head1 AUTHORS

Lyn St George <info@zolotek.net>, based on original code by Mike Heins
<mike@perusion.com> and others.

=head1 CREDITS

Hillary Corney (designersilversmiths.co.uk), Jamie Neil (versado.net),
Andy Mayer (andymayer.net) for testing and suggestions.

=head1 LICENSE

GPLv2

=cut

use strict;

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

    ::logGlobal("%s v2.1.2 payment module initialised, using %s", __PACKAGE__, $selected)
        unless $Vend::Quiet;

}

package Vend::Payment;

sub protx {

    my ($vendor, $amount, $actual, $opt);

    # Amount sent to Protx, in 2 decimal places with any cruft removed.
    # Defaults to 'amount' from the Accounts IPM or an invoicing system, falling back to IC input
    $amount =  $::Values->{amount} || Vend::Interpolate::total_cost();
    $amount =~ s/^\D+//g;
    $amount =~ s/,//g;
    $amount =  sprintf '%.2f', $amount;

    # Transaction type sent to Protx.
    my $txtype = $::Values->{transtype} || charge_param('txtype') || $::Variable->{MV_PAYMENT_TRANSACTION} || 'PAYMENT';
    my $accountType = $::Values->{account_type} || charge_param('account_type') || 'E';
    my $payID  = $::Values->{inv_no} || $::Session->{mv_transaction_id} || $::Session->{id}.$amount;

    my $logdir;

    # is logdir allowed to come from user?
    if (charge_param('logdir_from_user_allowed')) {
        $logdir = $::Values->{logdir};
    }
    elsif ($::Values->{logdir}) {
        ::logError("%s: user-specified logdir not allowed without route logdir_from_user 1", __PACKAGE__);
    }

    # was logdir specified in route?
    $logdir ||= charge_param('logdir');
    my $default_logdir = '/tmp';
    if (! $logdir) {
        $logdir = $default_logdir;
    }
    # validate logdir is valid
    elsif (! Vend::File::allowed_file("$logdir/TEST_FILE_NAME")) {
        ::logError("%s: using logdir %s instead of disallowed %s", __PACKAGE__, $default_logdir, $logdir);
        $logdir = $default_logdir;
    }
    $logdir = Vend::File::make_absolute_file($logdir);

    my $logzero    = charge_param('logzero')    || 'no';
    my $available  = charge_param('available')  || 'no';
    my $logempty   = $::Values->{logempty} || charge_param('logempty') || 'no';
    my $double_pay = $::Values->{double_pay} || charge_param('double_pay') || 'no';
    my $findcard   = charge_param('find_card_type') || 'no'; # yes for auto, page for input, no for IC
    my $description = charge_param('description') || $::Variable->{COMPANY};
    $description = substr($description,0,99);
    my $applyAVSCV2 = $::Values->{applyavscv2} || charge_param('applyavscv2') || '0';

    # if payment is logged as made, raise an error message and exit
    my $marker;
    if ($txtype =~ /DEFERRED/i) {
        $marker = "$logdir/pre-$payID";
    }
    else {
        $marker = "$logdir/paid-$payID";
    }

    my %result;

    # check for double payment only if using the payment terminal or making an invoice payment. Allow the
    # payment terminal to override this check to 'off' and allow identical amounts to be processed within
    # the same session.
    if (($::Values->{mv_order_route} =~ /ptipm_route|protx_vt_route/i) and (-e $marker) and ($double_pay eq 'yes')) {
        unless ($txtype =~ /REFUND|VOID|ABORT/) {
            $result{MErrMsg} = "Payment for this transaction $marker has already been made - thank you";
            return %result;
        }
    }
    # wrap around everything to bottom
    else {
        my %actual = map_actual();
        $actual  = \%actual;
        $opt     = {};

#::logDebug("actual map result: " . ::uneval($actual));
        $vendor   = $opt->{id} || charge_param('id') || $::Variable->{MV_PAYMENT_ID};
        $opt->{host}   = charge_param('host') || $::Variable->{MV_PAYMENT_HOST} || 'ukvpstest.protx.com';
        $opt->{use_wget} = charge_param('use_wget') || '1';
        $opt->{port}   = '443';

        if ($txtype =~ /DEFERRED|PAYMENT|AUTHENTICATE|PREAUTH/i) {
            $opt->{script} = '/vspgateway/service/vspdirect-register.vsp';
        }
        elsif ($txtype =~ /RELEASE/i) {
            $opt->{script} = '/vspgateway/service/release.vsp';
        }
        elsif ($txtype =~ /DIRECTREFUND/i) {
            $opt->{script} = '/vspgateway/service/directrefund.vsp';
        }
        elsif ($txtype =~ /REFUND/i) {
            $opt->{script} = '/vspgateway/service/refund.vsp';
        }
        elsif ($txtype =~ /VOID/i) {
            $opt->{script} = '/vspgateway/service/void.vsp';
        }
        elsif ($txtype =~ /CANCEL/i) {
            $opt->{script} = '/vspgateway/service/cancel.vsp';
        }
        elsif ($txtype =~ /ABORT/i) {
            $opt->{script} = '/vspgateway/service/abort.vsp';
        }
        elsif ($txtype =~ /MANUAL/i) {
            $opt->{script} = '/vspgateway/service/manualpayment.vsp';
        }
        elsif ($txtype =~ /REPEAT|REPEATDEFERRED/i) {
            $opt->{script} = '/vspgateway/service/repeat.vsp';
        }
        elsif ($txtype =~ /AUTHORISE/i) {
            $opt->{script} = '/vspgateway/service/authorise.vsp';
        }

        my @override = qw/
            order_id
            mv_credit_card_exp_month
            mv_credit_card_exp_year
            mv_credit_card_start_month
            mv_credit_card_start_year
            mv_credit_card_issue_number
            mv_credit_card_number
        /;
        for(@override) {
            next unless defined $opt->{$_};
            $actual->{$_} = $opt->{$_};
        }

        my $ccnum = $actual->{mv_credit_card_number};
        $ccnum =~ s/\D//g;
        $actual->{mv_credit_card_exp_month}    =~ s/\D//g;
        $actual->{mv_credit_card_exp_year}     =~ s/\D//g;
        $actual->{mv_credit_card_exp_year}     =~ s/\d\d(\d\d)/$1/;

        my $startDateMonth = $actual->{mv_credit_card_start_month} || $::Values->{mv_credit_card_start_month} || $::Values->{start_date_month} || 01;
        $startDateMonth =~ s/\D//g;

        my $startDateYear = $actual->{mv_credit_card_start_year} || $::Values->{mv_credit_card_start_year} || $::Values->{start_date_year} || 06;
        $startDateYear =~ s/\D//g;
        $startDateYear =~ s/\d\d(\d\d)/$1/;

        my $issue = $actual->{mv_credit_card_issue_number} || $::Values->{mv_credit_card_issue_number} || $::Values->{card_issue_number};
        $issue =~ s/\D//g;

        my $cvv2  = $actual->{mv_credit_card_cvv2} || $::Values->{cvv2};
        $cvv2  =~ s/\D//g;

        # overide the configured AVSCV2 setting
        if($txtype =~ /REPEAT|RELEASE|REFUND/i) {
            $applyAVSCV2 = '2';
        }

        my $exp = sprintf '%02d%02d', $actual->{mv_credit_card_exp_month}, $actual->{mv_credit_card_exp_year};

        my $startDate;
        if (!$startDateMonth) {
            $startDate = '';
        }
        else {
            $startDate = sprintf '%02d%02d', $startDateMonth, $startDateYear;
        }

        my $cardType;

        if ($::Values->{mv_credit_card_type}) {
            $cardType = $::Values->{mv_credit_card_type};
        }
        else {
            if ($ccnum =~ /^4(?:5085[0-9]|91880)\d{10}$/)                     {$cardType = 'UKE'}
            elsif ($ccnum =~ /^4917(?:3[0-3]|4(?:[0-2]|[9])|5[28])\d{10}$/)   {$cardType = 'UKE'}

            elsif ($ccnum =~ /^4462[0-9][0-9]\d{10}$/)                        {$cardType = 'Delta'}
            elsif ($ccnum =~ /^45(?:397[89]|4313|443[2-5])\d{10}$/)           {$cardType = 'Delta'}
            elsif ($ccnum =~ /^4547(?:[2][5-9]|[3][0-9]|[4][0-5])\d{10}$/)    {$cardType = 'Delta'}
            elsif ($ccnum =~ /^49(?:09[67][0-9]|218[12]|8824)\d{10}$/)        {$cardType = 'Delta'}

            elsif ($ccnum =~ /^6011\d{12}$/)                                  {$cardType = 'Discover'}
            elsif ($ccnum =~ /^3(?:6\d{12}|0[0-5]\d{11})$/)                   {$cardType = 'Dinersclub'}
            elsif ($ccnum =~ /^38\d{12}$/)                                    {$cardType = 'Carteblanche'}
            elsif ($ccnum =~ /^2(?:014|149)\d{11}$/)                          {$cardType = 'Enroute'}
            elsif ($ccnum =~ /^(?:3\d{15}|2131\d{11}|1800\d{11})$/)           {$cardType = 'JCB'}

            elsif ($ccnum =~ /^490(?:30[2-9]|33[5-9]|340|52[5-9])\d{10,12}$/) {$cardType = 'MAESTRO'}
            elsif ($ccnum =~ /^4911(?:0[0-2]|7[4-9]|8[0-2])\d{12,14}$/)       {$cardType = 'MAESTRO'}
            elsif ($ccnum =~ /^4936[0-9][0-9]\d{10,13}$/)                     {$cardType = 'MAESTRO'}
            elsif ($ccnum =~ /^564182\d{10}$/)                                {$cardType = 'MAESTRO'}
            elsif ($ccnum =~ /^633(?:110|3[0-9][0-9]|461)\d{10,12,13}$/)      {$cardType = 'MAESTRO'}
            elsif ($ccnum =~ /^6759\d{12,14,15}$/)                            {$cardType = 'MAESTRO'}

            elsif ($ccnum =~ /^49030[2-9]\d{12}$/)                            {$cardType = 'Solo'}
            elsif ($ccnum =~ /^63345[0-9]\d{10}$/)                            {$cardType = 'Solo'}
            elsif ($ccnum =~ /^63346([0]|[2-9])\d{10}$/)                      {$cardType = 'Solo'}
            elsif ($ccnum =~ /^6334[7-9][0-9]\d{10,12,13}$/)                  {$cardType = 'Solo'}
            elsif ($ccnum =~ /^6767[0-9][0-9]\d{10,12,13}$/)                  {$cardType = 'Solo'}

            elsif ($ccnum =~ /^4(?:\d{12}|\d{15})$/)                          {$cardType = 'Visa'}
            elsif ($ccnum =~ /^5[1-5]\d{14}$/)                                {$cardType = 'MC'}
            elsif ($ccnum =~ /^3[47]\d{13}$/)                                 {$cardType = 'Amex'}
        }

        # Mastercard require Maestro to use 3ds now.
        if ($cardType =~ /Switch|Maestro/i) {
            $result{MStatus} = $result{'pop.status'} = 'failed';
            $result{MErrMsg} = "Sorry, we do not accept Maestro cards";
            return %result;
        }

        my $cardRef = $actual->{mv_credit_card_number};
        $cardRef =~ s/^(\d\d).*(\d\d\d\d)$/$1****$2/;

        # Prefer billing values but fall back to shipping values.
        my $billingAddress  = sprintf '%s, %s, %s, %s',
            $actual->{b_address} || $actual->{address},
            $actual->{b_city}    || $actual->{city},
            $actual->{b_state}   || $actual->{state},
            $actual->{b_country} || $actual->{country};

        my $deliveryAddress = sprintf '%s, %s, %s, %s',
            $actual->{address},
            $actual->{city},
            $actual->{state},
            $actual->{country};

        my $cardHolder = $actual->{b_name} || '$actual->{b_fname} $actual->{b_lname}'
            || $actual->{name} || '$actual->{fname} $actual->{lname}';

        my $billingPostCode   = $actual->{b_zip}  || $actual->{zip};
        my $deliveryPostCode  = $actual->{zip}    || $actual->{b_zip};
        my $customerName      = $actual->{name}   || '$actual->{fname} $actual->{lname}' || $cardHolder;
        my $contactNumber     = $actual->{phone_day} || $actual->{phone_night};
        my $customerEmail     = $actual->{email};
        my $contactFax        = $::Values->{fax} || '';
        my $giftAidPayment    = $::Values->{giftaidpayment} || charge_param('giftaidpayment') || '0';
        my $authCode          = $::Values->{authcode} || '';
        my $clientIPAddress   = $CGI::remote_addr;

        # VendorTxCode generated here.
        my $vendorTxCode;
        my $order_id = gen_order_id($opt);
        if ($txtype =~ /RELEASE|VOID|ABORT/i) {
            $vendorTxCode = $::Values->{OrigVendorTxCode};
        }
        else {
            $vendorTxCode = $order_id;
        }

        # ISO currency code sent to Protx, from the page or fall back to config files.
        my $currency = $::Values->{iso_currency_code} || $::Values->{currency_code} || $Vend::Cfg->{Locale}{iso_currency_code}
            || charge_param('currency') || $::Variable->{MV_PAYMENT_CURRENCY} || 'GBP';

        my $psp_host = $opt->{host};

        # The string sent to Protx.
        my %query = (
            TxType                      => $txtype,
            VendorTxCode                => $vendorTxCode,
            Vendor                      => $vendor,
            AccountType                 => $accountType,
            VPSProtocol                 => '2.22',
            Apply3DSecure               => '2',
        );
        if ($txtype =~ /REFUND|REPEAT|AUTHORISE/) {
            $query{RelatedVPSTxID}      = $::Values->{RelatedVPSTxID};
            $query{RelatedVendorTxCode} = $::Values->{RelatedVendorTxCode};
            $query{RelatedSecurityKey}  = $::Values->{RelatedSecurityKey};
            $query{Description}         = $description;
            $query{Amount}              = $amount;
        }
        if ($txtype =~ /REFUND|REPEAT/) {
            $query{RelatedTxAuthNo}     = $::Values->{RelatedTxAuthNo};
            $query{Currency}            = $currency;
        }
        if ($txtype =~ /VOID|ABORT|CANCEL/i) {
            $query{VPSTxID}             = $::Values->{OrigVPSTxID};
            $query{SecurityKey}         = $::Values->{OrigSecurityKey};
        }
        if ($txtype =~ /VOID|ABORT/i) {
            $query{TxAuthNo}            = $::Values->{OrigTxAuthNo};
        }
        if ($txtype =~ /DIRECTREFUND|DEFERRED|PAYMENT|PREAUTH|AUTHENTICATE|MANUAL/i) {
            $query{CardType}            = $cardType;
            $query{CardNumber}          = $ccnum;
            $query{IssueNumber}         = $issue;
            $query{CardHolder}          = $cardHolder;
            $query{Description}         = $description;
            $query{Amount}              = $amount;
            $query{Currency}            = $currency;
            $query{StartDate}           = $startDate;
            $query{ExpiryDate}          = $exp
        }
        if ($txtype =~ /PAYMENT|DEFERRED|PREAUTH|AUTHENTICATE|MANUAL/i) {
            $query{BillingAddress}      = $billingAddress;
            $query{DeliveryAddress}     = $deliveryAddress;
            $query{BillingPostCode}     = $billingPostCode;
            $query{DeliveryPostCode}    = $deliveryPostCode;
            $query{CustomerName}        = $customerName;
            $query{ContactNumber}       = $contactNumber;
            $query{ContactFax}          = $contactFax;
            $query{CustomerEmail}       = $customerEmail;
            $query{GiftAidPayment}      = $giftAidPayment;
            $query{ClientIPAddress}     = $clientIPAddress;
            $query{AuthCode}            = $authCode;
            $query{CV2}                 = $cvv2;
        }
        if ($txtype =~ /PAYMENT|DEFERRED|PREAUTH|AUTHENTICATE|AUTHORISE/i) {
            $query{ApplyAVSCV2}         = $applyAVSCV2;
        }

#::logDebug("Sent to Protx: " . ::uneval(\%query));

        # Test for gateway availability, and if not available optionally go off-line and complete
        # transaction for manual processing later. Also go off-line if amount is zero, so as to log the
        # transaction and email a receipt for audit purposes (useful mainly for subscription billing).

        my ($request, $in);

#::logDebug("Protx809: available=$available, amount=$amount, order_route=$::Values->{mv_order_route}, logzero=$logzero\n");

        if (($available eq 'yes') and ($amount > 0) and ($::Values->{mv_order_route} !~ /ptipm_route|protx_vt_route/i)) {
            my $CMD = '/usr/bin/wget -nv --spider -T9 -t1';
            open (my $in, "$CMD https://$psp_host 2>&1 |") || die "Could not open pipe to wget: $!\n";
            $in = <$in>;
            close $in;
            # $in = 'test';   # testing only, will force offline mode
            if ($in =~ /^200 OK$/) {
                $request = 'psp';
            }
            else {
                $request = 'offline';
            }
        }
        elsif (($::Values->{mv_order_route} =~ /ptipm_route|protx_vt_route/i)  and ($amount > 0)) {
            $request = 'psp';
        }
        elsif (($available ne 'yes') and ($amount > 0)) {
            $request = 'psp';
        }
        elsif (($amount == 0) and ($logzero eq 'yes')) {
            $request = 'log';
        }

        if ($request eq 'psp') {

            my $post     = post_data($opt, \%query);
            my $response = $post->{status_line};
            my $page     = $post->{result_page};

#::logDebug("Response from Protx:\n$page \nend of response from Protx\n\n");

            $result{TxType}         = $txtype;
            $result{Currency}       = $currency;
            $result{CardRef}        = $cardRef;
            $result{CardType}       = $cardType;
            $result{ExpAll}         = $exp;
            $result{amount}         = $amount;
            $result{request}        = $request;
            $result{IP}             = $clientIPAddress;
            if ($cardType eq 'UKE') { $result{CardType} = 'Electron'; }
            $result{CardInfo}       = "$result{CardType}, $cardRef, $actual->{mv_credit_card_exp_month}/$actual->{mv_credit_card_exp_year}";

            for my $line (split /\r\n/, $page) {
                if ($line =~ /VPSTxID=(.*)/i) { $result{VPSTxID} = $1; }
                if ($line =~ /^Status=(.*)/i) { $result{Status} = $1; }
                if ($line =~ /StatusDetail=(.*)/i) { $result{StatusDetail} = $1; }
                if ($line =~ /TxAuthNo=(.*)/i) { $result{TxAuthNo} = $1;}
                if ($line =~ /SecurityKey=(.*)/i) { $result{SecurityKey} = $1; }
                if ($line =~ /AVSCV2=(.*)/i) { $result{AVSCV2} = $1; }
                if ($line =~ /VPSProtocol=(.*)/i) { $result{VPSProtocol} = $1; }
                if ($line =~ /AddressResult=(.*)/i) { $result{AddressResult} = $1; }
                if ($line =~ /PostCodeResult=(.*)/i) { $result{PostCodeResult} = $1; }
                if ($line =~ /CV2Result=(.*)/i) { $result{CV2Result} = $1; }
            }

            if ($txtype =~ /PAYMENT|DEFERRED|MANUAL|PREAUTH|AUTHENTICATE|AUTHORISE/i) {

                if ($result{Status} =~ /OK$|REGISTERED/i) {
                    $result{MStatus} = $result{'pop.status'} = 'success';
                    $result{'order-id'} ||= $opt->{order_id};
                }
                elsif ($result{Status} !~ /OK$|REGISTERED/i)  {
                    $result{MStatus} = $result{'pop.status'} = 'failed';
                    if ($result{StatusDetail} =~ /AVS/i) {
                        $result{MErrMsg} =  "Data mismatch<br>Please ensure that your address matches the address on your credit-card statement, and that the card security number matches the code on the back of your card\n";
                    }
                    else {
                        $result{MErrMsg} = "$result{StatusDetail} $result{Status}";
                    }
                }
                elsif (!$result{Status}) {
                # If the status response is read as empty, the customer will try to repeat the order. This next
                # will force the transaction to success in this case, thus preventing any attempt to repeat the
                # order, but flag it so that the merchant knows to manually check with Protx to see if they have
                # a valid transaction. There are different views on this approach - use with care.
                    if ($logempty eq 'yes') {
                        $result{MStatus} = $result{'pop.status'} = 'success';
                        $result{'order-id'} ||= $opt->{order_id};
                        $result{TxType} = 'NULL';
                        $result{StatusDetail} = 'UNKNOWN status - check with Protx before dispatching goods';
                    }
                }
                else {
                    $result{MStatus} = $result{'pop.status'} = 'failed';
                    $result{MErrMsg} = "$result{StatusDetail}";
                }
            }

            # these next can only be done through a virtual terminal
            elsif($txtype =~ /RELEASE|REPEAT|REFUND|DIRECTREFUND|VOID|ABORT/i ) {
                if ($result{Status} =~ /OK|REGISTERED/i) {
                    $result{MStatus} = $result{'pop.status'} = 'success';
                    $result{'order-id'} ||= $opt->{order_id};
                }
                else {
                    $result{MStatus} = $result{'pop.status'} = 'failed';
                    $result{MErrMsg} = "$result{Status} $result{StatusDetail}";
                }
            }
        }
        elsif ($request eq 'offline') {
            # end of PSP request, now for either OFFLINE or LOG
            # force result to 'success' so that transaction completes off-line
            $result{MStatus} = 'success';
            $result{'order-id'} ||= $opt->{order_id};
            $result{TxType} = 'OFFLINE';
        }
        elsif ($request eq 'log') {
            # force result to 'success' so that transaction completes off-line
            $result{MStatus} = 'success';
            $result{'order-id'} ||= $opt->{order_id};
            $result{TxType} = 'LOG';
        }

        # if payment is confirmed as OK by Protx, log this for checking above
#        if ($result{Status} =~ /OK|REGISTERED/i) {
            if (open my $touch, '>>', $marker) {
                close $touch;
            }
            else {
                ::logError("%s: error updating timestamp of %s: %s", __PACKAGE__, $marker, $!);
            }
#        }

    } # close double payment marker

    return %result;
}

package Vend::Payment::Protx2;

1;
