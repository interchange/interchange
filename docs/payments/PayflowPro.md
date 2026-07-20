# PayflowPro (Vend::Payment::PayflowPro)

Charges cards through PayPal's Payflow Pro HTTPS POST API. The same module
also drives PayPal Express Checkout (set/get/do requests against a linked
PayPal account) when the tag/call includes an `action`.

## Prerequisites

`LWP`, `Crypt::SSLeay`, `HTTP::Request`, `HTTP::Headers`, and OpenSSL. A
Payflow Pro account (partner, vendor, user, password); for Express
Checkout, a PayPal account linked to that Payflow Pro/Manager account.

## Configuration

    Require module Vend::Payment::PayflowPro     # interchange.cfg

    Variable  MV_PAYMENT_MODE  payflowpro         # catalog.cfg
    Route  payflowpro  id      YourPayflowProID
    Route  payflowpro  secret  YourPayflowProPassword

| Option | Default | Meaning |
|---|---|---|
| `id` | (required) | PayPal-assigned account ID (`USER`). Also settable as `MV_PAYMENT_ID`. |
| `secret` | (required) | Account password (`PWD`). Also settable as `MV_PAYMENT_SECRET`. |
| `partner` | (unset) | Account partner (`PARTNER`). Also settable as `MV_PAYMENT_PARTNER`. |
| `vendor` | (unset) | Account vendor (`VENDOR`). Also settable as `MV_PAYMENT_VENDOR`. |
| `test` | (unset) | If true and `host` is unset, posts to `pilot-payflowpro.paypal.com` instead of `payflowpro.paypal.com`. |
| `host` | `payflowpro.paypal.com` (or the pilot host under `test`) | Gateway host to override. |
| `port` | `443` | Gateway port. |
| `timeout` | `45` | Seconds to wait for the HTTPS response; also sent as `X-VPS-Timeout`. |
| `precision` | `2` | Decimal places used when rounding order totals if no explicit amounts are supplied. |
| `accept_for_review` | (unset) | With PayPal's Fraud Protection Service, set to `1` to accept orders that were merely flagged (`RESULT` 126/127) instead of declining them. |
| `check_sub` | (unset) | Name of a `Sub`/`GlobalSub` called with the result hash and transaction type after an approval/flag response, to decline on bad AVS/CVV. Return true to accept, false to decline. Ignored for PayPal (`TENDER=P`) transactions. |
| `returnurl` | (required for Express Checkout) | URL PayPal returns the buyer to after approval (`RETURNURL`). |
| `cancelurl` | (required for Express Checkout) | URL to send the buyer to if they cancel (`CANCELURL`). |
| `allow_note` | (unset) | `ALLOWNOTE` — allow the buyer to add a note at PayPal. |
| `reqbillingaddress` | (unset) | `REQBILLINGADDRESS`. |
| `reqconfirmshipping` | (unset) | `REQCONFIRMSHIPPING` — require a "confirmed" PayPal address. |
| `pagestyle` | (unset) | `PAGESTYLE`, configured at PayPal. |
| `headerimg` | (unset) | `HDRIMG` — custom header image URL shown during the PayPal session. |
| `headerbordercolor`, `headerbackcolor`, `payflowcolor` | (unset) | `HDRBORDERCOLOR`, `HDRBACKCOLOR`, `PAYFLOWCOLOR` — Express Checkout page styling. |
| `addressoverride` | (referenced in POD) | Ship only to the address already on file in Interchange; the customer must be logged in first. Not read as a `charge_param` by this version of the code — set via order-profile logic instead. |
| `use_billing_override` | (referenced in POD) | Send the billing address instead of shipping to PayPal. Not read as a `charge_param` by this version of the code. |
| `note_to_buyer` | `*** Discounts and coupons will be shown and applied before final payment` | `NOTETOBUYER`. |
| `gwl_enabled` | (unset) | Enables gateway request/response logging via [GatewayLog](GatewayLog.md); also `MV_PAYMENT_GWL_ENABLED`. |
| `gwl_table` | `gateway_log` | Logging table name; also `MV_PAYMENT_GWL_TABLE`. |
| `gwl_source` | `` `hostname -s` `` | Logging source label; also `MV_PAYMENT_GWL_SOURCE`. |
| `remap`, `host` (rare use) | | Remap standard form-variable names to PayPal's; override the default host. |

## Transaction types

Set with the `transaction` option, default `auth`:

| Interchange | Payflow Pro `TRXTYPE` |
|---|---|
| `sale`, `mauthcapture` | `S` |
| `auth`, `authorize`, `mauthonly` | `A` |
| `credit`, `mauthreturn` | `C` |
| `void` | `V` |
| `settle`, `settle_prior`, `mauthdelay` | `D` — captures a prior `A` |

Card and address fields are only sent for `TENDER=C` (regular card)
transactions or when completing/voiding a PayPal (`TENDER=P`) order;
`TENDER` is automatically set to `P` once the order's stored
`payment_method` starts with `PayPal`.

For PayPal Express Checkout, pass `action=set` (redirect the buyer to
PayPal), `action=get` (read back the buyer's chosen address once they
return), or `action=do` (capture the payment) as tag options — these map
internally to Payflow Pro's `ACTION=S/G/D`. See the module's own POD for
the full page-by-page walkthrough (`ord/paypalgetrequest`,
`ord/paypalsetrequest`, `ord/paypalcheckout`, and the `etc/log_transaction`
and `etc/profiles.order` edits it requires).

## Testing

Set `Route payflowpro test 1` (with no explicit `host`) to use PayPal's
pilot/test environment. Then try a sale with card number `4111 1111 1111
1111` and a valid future expiration date; it should be denied, with the
reason in `[data session payment_error]`.

## Examples

Minimal card-only configuration:

    Require module Vend::Payment::PayflowPro

    Variable  MV_PAYMENT_MODE  payflowpro
    Route  payflowpro  id      YourPayflowProID
    Route  payflowpro  secret  YourPayflowProPassword
    Route  payflowpro  partner PayPal

Charging the order total through the route:

    [charge route="payflowpro"]

## See also

[Payment processing concepts](../guides/payments.md), [PaypalExpress](PaypalExpress.md),
[GatewayLog](GatewayLog.md), [charge](../tags/charge.md), [Route](../config/Route.md).

## Source

`lib/Vend/Payment/PayflowPro.pm`. The module's own POD documents `id`,
`secret`, `partner`, `vendor`, `transaction`, `accept_for_review`,
`check_sub`, and the full PayPal Express Checkout option set
(`returnurl`, `cancelurl`, `headerimg`, `reqconfirmshipping`,
`addressoverride`, `use_billing_override`, `remap`, `host`); verified
against the `payflowpro()` routine, which also reads `test`, `port`,
`timeout`, `precision`, and the `gwl_*` logging options (the latter
documented only in [GatewayLog](GatewayLog.md), not in this module's own
POD). The POD lists `addressoverride` and `use_billing_override` as
options, but the current code does not call `charge_param` for either —
an honest gap between the POD and the code.
