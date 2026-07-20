# CyberSource (Vend::Payment::CyberSource)

Charges, authorizes, captures, credits, and voids transactions through
CyberSource's SOAP "Simple Order API" (a SOAP clientless toolkit that
impersonates CyberSource's older Simple API). Beyond plain credit-card
processing (`acct_type=cc`), it also fully implements CyberSource's Bill Me
Later (`bml`), PayPal Express Checkout (`pp`), and Electronic Check (`ec`)
account types. This module supersedes [ICS](ICS.md), which used
CyberSource's older SCMP API; CyberSource no longer allows new merchants to
use SCMP, so all new integrations must use this module.

**Important:** unlike most Interchange payment modules, this one deliberately
does *not* fall back to `Variable MV_PAYMENT_*` for most of its settings (the
module's own POD calls that fallback path "unwise" since it cannot be scoped
to one route). Except for `transaction`, `currency`, and the `gwl_*` logging
options, every setting below must be supplied via a `Route` or directly on
the `[charge]`/`&charge` call — it is read straight from the options hash,
not through `charge_param()`.

## Prerequisites

- `SOAP::Lite`
- `XML::Pastor::Schema::Parser`
- `LWP::Simple`
- OpenSSL
- Do **not** install CyberSource's "Simple API" client; this module only
  needs the SOAP toolkit dependencies above.
- A CyberSource merchant account with a transaction key generated from the
  online merchant interface (not the same as the legacy `ecert()`-generated
  key used by [ICS](ICS.md)).

## Configuration

    Require module Vend::Payment::CyberSource        # interchange.cfg
    Variable MV_PAYMENT_MODE cybersource              # catalog.cfg (informational only; see note above)
    Route  cybersource  merchant_id       YourMerchantID
    Route  cybersource  transaction_key   YourTransactionKey
    Route  cybersource  api_version       1.145
    Route  cybersource  live              false

Make sure `CreditCardAuto` is off. Always call through a named `Route` (the
module's own documentation strongly recommends this over passing everything
on `[charge]`) — for example `[charge route=cybersource]`.

| Option              | Default              | Meaning |
|---------------------|----------------------|---------|
| `merchant_id`       | none (required)      | CyberSource merchant ID. |
| `transaction_key`   | none (required)      | Transaction key from the CyberSource merchant interface. |
| `api_version`       | none (required)      | Simple API schema version to request, e.g. `1.145`. |
| `live`              | test environment      | The literal string `true` selects the production host (`ics2ws.ic3.com`/`www.paypal.com`); anything else uses the test host (`ics2wstest.ic3.com`/`www.sandbox.paypal.com`). |
| `xsd_cache_dir`     | none (no caching)     | Directory (relative to catroot) to cache the per-version, per-environment XSD schema CyberSource returns, so it need not be re-fetched on every request. |
| `acct_type`         | `cc`                  | `cc` (credit card), `bml` (Bill Me Later), `pp` (PayPal Express Checkout), or `ec` (electronic check). |
| `transaction`       | `auth`                | Requested transaction; see [Transaction types](#transaction-types). Falls back to `Variable MV_PAYMENT_TRANSACTION` if not set on the option/route. |
| `apps`               | none (all needed apps effectively disabled unless listed) | Space/comma-separated list of CyberSource "applications" this route is permitted to invoke (e.g. `ics_auth ics_bill`); restricts which service calls can run. |
| `origid`            | none                  | Original transaction's request ID, for follow-on capture/void/credit/reversal calls. |
| `order_id` / `order_number` | none           | Order identifier sent as `merchantReferenceCode`. `order_number` is preferred; `order_id` is copied to it if `order_number` is unset. |
| `ship_map`          | (unset; falls back to `lowcost`) | `qw()`-style list mapping your `mv_shipmode` values to CyberSource's `shipTo_shippingMethod` values (`sameday`, `oneday`, `twoday`, `threeday`, `lowcost`, `pickup`, `other`, `none`). |
| `items_sub`         | none (uses `$Vend::Items`) | Name of a `Sub`/`GlobalSub` that returns a cart-like array of line items (each needs `code` and `quantity`) for building the CyberSource item lines; useful when charging outside the current session (e.g. from the admin UI). |
| `check_sub`         | none                  | Name of a `Sub`/`GlobalSub` called as `$sub->(\%response, \%request_copy, $opt)` to override the success/failure determination or annotate the response. |
| `ip_address`        | `$Session->{shost}` or `$Session->{ohost}` | Customer IP address sent as `billTo_ipAddress`. |
| `shipping`          | `[shipping]` amount    | Shipping cost line item added to the request. |
| `handling`          | `[handling]` amount    | Handling cost line item added to the request. **Not documented in the module's own POD**, but read the same way as `shipping` (`$opt->{handling}`, defaulting to `$Tag->handling({ noformat => 1 })`). |
| `amount`            | derived from cart total | Overrides the computed order total sent to CyberSource (via the base `charge()`'s `total_cost`). |
| `timeout`           | none                  | Seconds to allow for a response before killing the request. |
| `merrmsg`           | built-in English text | `sprintf`-style override for the cc/bml decline message; may embed the reason code and reason message with `%s` placeholders, in that order. |
| `merrmsg_bml`       | built-in English text | Override for BML-specific failures (no `%s` placeholders supported). |
| `gwl_enabled`       | false                 | Enable [GatewayLog](GatewayLog.md) transaction logging. Read via `charge_param()`, so it can also be set with `Variable MV_PAYMENT_GWL_ENABLED`. |
| `gwl_table`         | `gateway_log`         | Table `GatewayLog` writes to. |
| `gwl_source`        | `` `hostname -s` `` output | Value stored in the log's `request_source` column. |

PayPal Express Checkout (`acct_type=pp`) adds many more options —
`returnurl`, `cancelurl`, `maxamount`, `billinginfo`, `useraction`,
`order_desc`, `confirmshipping`, `noshipping`, `addressoverride`, `locale`,
`headerbackcolor`, `headerbordercolor`, `headerimg`, `payflowcolor`,
`pp_token`, `pp_payer_id`, `return_ec_set`, `transaction_id` — all verified
present in the module's `%opt_map`/direct `$opt->{...}` reads. See the
module's own POD (`perldoc lib/Vend/Payment/CyberSource.pm`) for the full
PayPal, Bill Me Later, and Electronic Check walkthroughs; they are too
extensive to duplicate here in full.

Bill Me Later (`acct_type=bml`) additionally expects `bml_customer_registration_date`,
`bml_customer_type_flag`, `bml_item_category`, `bml_product_delivery_type_indicator`,
`bml_tc_version`, `customer_ssn`, and `date_of_birth` — typically wired up
with a `remap` on the route so they flow through `map_actual()` from your
order form.

## Transaction types

`acct_type cc` or `bml`:

| Interchange                    | CyberSource service |
|---------------------------------|----------------------|
| `sale`, `S`                     | `auth_bill` (auth + capture in one request) |
| `auth`, `authorize`, `A`        | `auth` |
| `settle`, `capture`, `D`        | `bill` |
| `credit`, `C`                   | `credit` |
| `auth_reversal`, `R`            | `auth_reversal` (not widely supported by processors; use with caution) |
| `void`, `V`                     | `void` |

`acct_type pp`: `pp_set`, `pp_get`, `pp_dopmt`, `pp_ord_setup`, `pp_auth`,
`pp_bill`, `pp_sale`, `pp_authrev`, `pp_refund`.

`acct_type ec`: `ec_debit`, `ec_credit`.

Each transaction type requires a matching entry in `apps` (e.g. `sale` needs
both `ics_auth` and `ics_bill`) or the module returns a hard failure.

## Testing

Set `live` to anything other than the literal string `true` (or leave it
unset) to use CyberSource's test environment. Switch to `true` for
production. There is no separate `test` option — `live` is the only switch.
In test mode, use CyberSource's documented test card numbers; in production,
`4111 1111 1111 1111` is guaranteed to decline and is useful for confirming
`[data session payment_error]` is populated correctly.

## Examples

Minimal `catalog.cfg` fragment for a plain credit-card sale:

    Variable MV_PAYMENT_MODE cybersource
    Route  cybersource  merchant_id      YourMerchantID
    Route  cybersource  transaction_key  YourTransactionKey
    Route  cybersource  api_version      1.145
    Route  cybersource  live             false
    Route  cybersource  apps             "ics_auth ics_bill"
    Route  cybersource  transaction      sale

Charging the current order:

    [charge route="cybersource"]

Authorize now, capture later against the resulting request ID:

    [charge route="cybersource" transaction="auth"]
    ...
    [charge route="cybersource" transaction="settle" origid="[data session payment_id]"]

Starting a PayPal Express Checkout session from the cart page:

    [button text="Checkout with Paypal" form=basket]
        [tmp redirect][charge route="paypal_set"][/tmp]
        [if scratch redirect][bounce href="[scratch redirect]"][/if]
    [/button]

with a route configured for the `pp_set` service:

    Route  paypal_set  gateway         cybersource
    Route  paypal_set  acct_type       pp
    Route  paypal_set  transaction     pp_set
    Route  paypal_set  apps            pp_ec_set
    Route  paypal_set  returnurl       ord/paypal_return
    Route  paypal_set  cancelurl       ord/basket

## See also

[Payment processing concepts](../guides/payments.md), [ICS](ICS.md),
[GatewayLog](GatewayLog.md).

## Source

`lib/Vend/Payment/CyberSource.pm` (has its own extensive POD covering
PayPal, Bill Me Later, and Electronic Check usage in detail). Uses
`Vend::Payment::CyberSourceGWL`, based on
[Vend::Payment::GatewayLog](GatewayLog.md), for optional transaction
logging.
