# Linkpoint (Vend::Payment::Linkpoint)

Charges cards through the LinkPoint Secure Payment Gateway (LSPG) using the
`lpperl` client library, which in turn uses `curl` to contact LinkPoint.
Supports authorize, sale, and prior-auth capture.

## Prerequisites

`lpperl` (v3.0.012 or later) and a working `curl` installed on the server.
Test with `perl -Mlpperl -e 'print "It works.\n"'`. A LinkPoint merchant
account (store number) and its RSA/certificate keyfile.

## Configuration

    Require module Vend::Payment::Linkpoint       # interchange.cfg

    Variable  MV_PAYMENT_MODE  linkpoint           # catalog.cfg
    Route  linkpoint  id       YourLinkpointID
    Route  linkpoint  keyfile  /path/to/merchant.pem

| Option | Default | Meaning |
|---|---|---|
| `id` | (required) | Store number assigned to your merchant account. Also settable as `MV_PAYMENT_ID`. Returns `failure-hard` ("No customer id") if missing. |
| `keyfile` | (required) | File containing the merchant's RSA private key and certificate. Returns `failure-hard` ("No certificate file") if missing. |
| `host` | `secure.linkpt.net` | LSPG hostname; use `staging.linkpt.net` for testing. |
| `precision` | `2` | Decimal places used when rounding the order total if no explicit amount is supplied. |
| `check_sub` | (unset) | Name of a `Sub`/`GlobalSub` called with the result hash after a LinkPoint approval, used to fail orders on bad AVS/CVV since LinkPoint itself never declines for that. Return true to accept, false to fail. |
| `debuglevel`, `curl_args` | (unset) | Passed straight through to `lpperl` as `debugging` and `cargs`. Set only via the tag/call options, not `Route`/`Variable`. |

## Transaction types

Set with the `transaction` option, default `sale`:

| Interchange | LinkPoint |
|---|---|
| `auth`, `authorize`, `mauthonly` | `PREAUTH` |
| `sale`, `mauthcapture` | `SALE` |
| `settle_prior` | `POSTAUTH` |

`PREAUTH` and `SALE` are the only transaction types eligible for
`check_sub`; a `POSTAUTH` skips it, and also drops shipping, tax, and card
detail fields from the request since they aren't needed to capture a prior
authorization.

## Testing

Point `host` at `staging.linkpt.net` with a test store number and keyfile.

## Examples

Minimal auth-only configuration with an AVS/CVV check:

    Require module Vend::Payment::Linkpoint

    Variable  MV_PAYMENT_MODE  linkpoint
    Route  linkpoint  id        YourLinkpointID
    Route  linkpoint  keyfile   /etc/interchange/linkpoint.pem
    Route  linkpoint  transaction  auth
    Route  linkpoint  check_sub  link_check

Matching `GlobalSub` in `interchange.cfg`:

    GlobalSub <<EOR
    sub link_check {
        my ($result) = @_;
        my $avs = $result->{r_avs};
        my ($addr, $zip, $nothing, $cvv) = split m{}, $avs;
        return 1 if $addr eq 'Y' or $zip eq 'Y';
        return 1 if $addr eq 'X' and $zip eq 'X';
        return 1 if $cvv =~ /^[MPSUX]$/;
        $result->{MStatus} = 'failure';
        $result->{r_error} = $cvv =~ /^N?$/
            ? "The card security code you entered does not match."
            : "The billing address you entered does not match the cardholder's billing address.";
    }
    EOR

Charging the order total through the route:

    [charge route="linkpoint"]

## See also

[Payment processing concepts](../guides/payments.md), [charge](../tags/charge.md),
[Route](../config/Route.md).

## Source

`lib/Vend/Payment/Linkpoint.pm` (module POD documents `host`, `keyfile`,
`id`, `transaction`, and `check_sub`; verified against the `linkpoint()`
routine, which also reads `precision`, `debuglevel`, and `curl_args`).
