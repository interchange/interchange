# HSBC (Vend::Payment::HSBC)

Charges cards through the HSBC/GlobalIris ePayments gateway (formerly
eSecurePayments), including its 3-D Secure (3DS) cardholder-authentication
flow and a configurable set of fraud-screening rules.

## Prerequisites

- `XML::Simple`
- `XML::Parser`
- `URI`
- `libwww-perl` (`LWP`)
- `Net::SSLeay`
- `HTTP::Request`
- `MIME::Base64`

Test with `perl -MXML::Simple -e 'print "It works\n"'` and similarly for the
others. An HSBC/GlobalIris merchant account, with a client ID and client
alias per currency you accept, and a gateway username/password.

## Configuration

    Require module Vend::Payment::HSBC        # interchange.cfg

    Variable  MV_PAYMENT_MODE  hsbc            # catalog.cfg
    Route  hsbc  username       XXnnnnnn
    Route  hsbc  password       xxx
    Route  hsbc  clientidGBP    nnnnn
    Route  hsbc  clientalias    XXnnnnnnnn

`clientidGBP` illustrates the pattern: the module looks up
`clientid<CURRENCY>`, so set one `Route` line per currency you take
(`clientidEUR`, `clientidUSD`, and so on).

| Option | Default | Meaning |
|---|---|---|
| `gwhost` | `https://apixml.globaliris.com` | Gateway host posted to for `gwpost` requests. |
| `tdshost` | `https://mpi.globaliris.com/ccpa` | Payment Authentication Server (PAS) host for the 3DS lookup. |
| `bypass3ds` | (unset) | Read from the `bypass3ds` value/option; not otherwise interpreted by this version of the module (present for future use). |
| `hsbcrequest` | `gwpost` | Which leg of the flow to run: `tdspost` (send card to PAS) or `gwpost` (post to the gateway, optionally after a `tdsreturn`). |
| `tdsreturn` | (unset) | Set (as a value) when returning from the PAS; forces `hsbcrequest` to `gwpost`. |
| `mail_txn_to` | `EMAIL_SERVICE` or `ORDERS_TO` variable | Merchant address for review/decline/approval notices. |
| `currency` | `GBP` | ISO currency code; also read from the `iso_currency_code` value/scratch. |
| `clientid<CURRENCY>` | (required) | Numeric client ID for that currency, e.g. `clientidGBP`. Dies with "No client ID" if missing. |
| `clientalias` | (required) | Merchant alias (country code + 8-digit account id); warns "No client Alias" if missing. |
| `username` | (required) | Gateway username; dies "No username id" if missing. |
| `lcusername` | (unset) | If it matches the current currency, lowercases `username` before sending. |
| `password` | (required) | Gateway password; dies "No password" if missing. |
| `txtype` | `Auth` | Transaction type; see Transaction types below. |
| `payment_type` | `Payment` | `Payment` runs HSBC's fraud checks; `PaymentNoFraud` bypasses them. |
| `txmode` | `P` | `P` production, `Y`/`N`/`R` test yes/no/random, `FY`/`FN` test FraudShield yes/no. |
| `hsbctdspage` | `ord/hsbctds` | Page the customer is bounced to to begin 3DS. |
| `returnurl` | `SECURE_SERVER` + `CGI_URL` + `/ord/hsbctdsreturn` | Return URL registered with the PAS. |
| `finalcheckoutpage` | `ord/checkout` | Read by the module but not otherwise used in this version. |
| `mail_txn_approved` | (unset) | Set to `1` to email the merchant on approval. |
| `mail_txn_declined` | (unset) | Set to `1` to email the merchant on decline. |
| `psp` | `HSBC` | Payment-service-provider label stored on the order when returning from 3DS. |
| `fraud_<N>` | (unset) | Per-rule action for fraud rule `<N>` (see below). |

### Fraud rules

HSBC returns zero or more numbered fraud alerts. For each rule number the
gateway can flag, set `Route hsbc fraud_<N> '<accept> <display>'`: the first
digit is `1` to accept the order despite the alert or `0` to reject it; the
second is `2` to show the rule's message to the customer or `0` to suppress
it. For example:

    Route hsbc fraud_6 '0 2'   # failed AVS check: reject and show a message
    Route hsbc fraud_9 '0 2'   # invalid billing name: reject and show a message

Any rule without a matching `fraud_<N>` Route falls through to rejection.
The displayed text is exposed to the page as `[scratch pspfraudmsg]`.

## Transaction types

Set with the `txtype` option (default `Auth`):

| `txtype` | HSBC meaning |
|---|---|
| `PreAuth` | Authorize only. |
| `Auth` | Authorize (module default). |
| `PostAuth` | Capture a prior `PreAuth`. |
| `Void` | Cancel an uncaptured authorization. |
| `Credit` | Refund. |
| `ForceInsertPreAuth`, `ForceInsertAuth` | Record a voice-authorized transaction (needs `authcode`). |
| `ReAuth`, `RePreAuth` | Re-run a periodic-billing authorization. |
| `ReviewPendingUpdate` | Update a transaction pending manual review. |

## Testing

Set `Route hsbc txmode` to `Y` (approve), `N` (decline), `R` (random), `FY`
or `FN` (FraudShield yes/no) instead of `P`. `txmode` can also be overridden
per-request from the `txmode` value.

## Examples

Minimal 3DS-enabled configuration for a GBP merchant:

    Require module Vend::Payment::HSBC

    Variable  MV_PAYMENT_MODE  hsbc
    Route  hsbc  username     XX123456
    Route  hsbc  password     s3cret
    Route  hsbc  clientidGBP  12345
    Route  hsbc  clientalias  GB1234567801
    Route  hsbc  txmode       Y

Charging the order total through the route from a checkout page:

    [charge route="hsbc" amount="[scratch tmp_remaining]" order_id="[value mv_transaction_id]"]

## See also

[Payment processing concepts](../guides/payments.md), [charge](../tags/charge.md),
[Route](../config/Route.md).

## Source

`lib/Vend/Payment/HSBC.pm`. The module carries its own POD with a full
walkthrough of the 3DS flow and catalog template edits; the option table
above was independently verified against the `hsbc()` routine.
