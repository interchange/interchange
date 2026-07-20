# Payment processing

This chapter explains how Interchange authorizes and captures money. One tag,
[charge](../tags/charge.md), drives every gateway; a **payment route** holds
the settings; a family of `MV_PAYMENT_*` variables fills in anything the route
omits. The chapter walks the charge from the ITL call through option
resolution, amount and currency handling, transaction types, and the result
hash you read to know whether it worked — then covers where a charge fits in
the order process, how to keep cardholder data out of harm's way, and how to
test a checkout end to end with no gateway account. It does not re-explain the
order process itself; [Carts and checkout](cart-and-checkout.md) owns that, and
this chapter is the payment step it hands off to. The individual gateway
drivers each have their own reference page under
[the payments reference](../payments/README.md); this chapter is the shared
model behind all of them.

The code authority is `lib/Vend/Payment.pm` — `charge()` (the transaction
driver), `charge_param()` (option resolution), and `map_actual()` (form-field
mapping). Each gateway driver lives in `lib/Vend/Payment/<Gateway>.pm` and
supplies its own subroutine and POD. Note that in this tree `Vend::Payment.pm`
itself carries no POD block; the model below is documented from its code.

## The charge model in one paragraph

Interchange never talks to a gateway from a storefront page directly. A charge
is a call to `Vend::Payment::charge`, reached through the
[charge](../tags/charge.md) tag or the `&charge` / `payment_mode` hooks in the
order process. `charge` takes a **charge type** — the name of a payment route —
loads that route's settings as a base, overlays any options passed on the tag,
figures the amount and currency, and dispatches to a **gateway** subroutine
(`Vend::Payment::authorizenet`, `Vend::Payment::testpayment`, and so on). The
gateway does the network call and returns a **result hash**; `charge` stores it
in the session and returns the transaction id. Everything else — which gateway,
which credentials, test mode, currency — is configuration read through one
accessor, `charge_param()`.

## The [charge] tag

[charge](../tags/charge.md) is a standalone tag whose first positional argument
is the route name; any further attributes become options passed to the gateway:

    [charge authorizenet]

    [charge route=authorizenet transaction=auth amount=19.95]

It maps to `Vend::Payment::charge($route, \%options)`. The tag returns the
gateway's transaction id (the result hash's `order-id`), **not** a success
flag — a declined card and an approved card both return a value. To branch on
success you read the result hash, described under
[Reading the result](#reading-the-result). A bare `[charge routename]` is the
common case: the route carries the credentials, and the amount defaults to the
order total.

`[charge]` is rarely typed on a page a shopper sees. In a real store it runs
from the order-routing report template inside
[try](../tags/try.md)/[catch](../tags/catch.md), or from a profile's `&charge`
directive — see [Where the charge runs](#where-the-charge-runs).

## Payment routes and MV_PAYMENT_* variables

A **payment route** is an ordinary [Route](../config/Route.md) whose name you
use as the charge type. It holds the gateway credentials and per-gateway
options, one attribute per line:

    Route  authorizenet  id       YourLoginID
    Route  authorizenet  secret   YourTransactionKey
    Route  authorizenet  test     1

Any option a gateway reads can *also* be supplied in
[Variable](../config/Variable.md) space as `MV_PAYMENT_<NAME>`. The two styles
are interchangeable; the route wins when both are set. This resolution is the
job of `charge_param()`, and every option in this chapter follows it. The order
`charge_param` checks is:

1. an option passed on the [charge](../tags/charge.md) tag (or in the `$opt`
   hash from `&charge`), then
2. the named payment route's attributes, then
3. the variable `MV_PAYMENT_<NAME>` (upper-cased option name), then
4. `undef`.

So `Route authorizenet id XYZ` and `Variable MV_PAYMENT_ID XYZ` set the same
`id` option; a store with a single gateway typically uses the `MV_PAYMENT_*`
variables, and a store juggling several gateways puts per-gateway values on the
routes. The variables are documented individually:

| Variable | Option | Purpose |
|----------|--------|---------|
| [MV_PAYMENT_MODE](../variables/MV_PAYMENT_MODE.md) | — | Which route/gateway the checkout charges through |
| [MV_PAYMENT_ID](../variables/MV_PAYMENT_ID.md) | `id` | Merchant/login id |
| [MV_PAYMENT_SECRET](../variables/MV_PAYMENT_SECRET.md) | `secret` | Password / transaction key / shared secret |
| [MV_PAYMENT_CURRENCY](../variables/MV_PAYMENT_CURRENCY.md) | `currency` | Currency code sent with the charge |
| [MV_PAYMENT_PRECISION](../variables/MV_PAYMENT_PRECISION.md) | `precision` | Decimal places in the formatted amount |
| [MV_PAYMENT_TEST](../variables/MV_PAYMENT_TEST.md) | `test` | Put the gateway in test/sandbox mode |

Many more options exist only per gateway (`host`, `port`, `partner`, `vendor`,
`remap`, `transaction`, `global_timeout`, the `gwl_*` logging keys, and so on).
Each is settable the same three ways; the option name upper-cased and prefixed
with `MV_PAYMENT_` gives its variable form. The
[per-gateway pages](../payments/README.md) list the options each driver
actually reads — always the authority for a given gateway, since the accepted
set and its defaults vary by module.

`charge_param()` is also the accessor a gateway driver uses internally, so if
you write your own driver you read every setting through it and inherit this
resolution for free.

## Selecting the gateway: MV_PAYMENT_MODE

[MV_PAYMENT_MODE](../variables/MV_PAYMENT_MODE.md) names the route the checkout
charges through. The strap demo's `log_transaction` template charges only when
it is set:

    Variable  MV_PAYMENT_MODE  authorizenet

Inside `charge`, the **gateway** defaults to the charge type (the route name)
unless a `gateway` option overrides it. That is why the route name, the
`MV_PAYMENT_MODE` value, and the `Vend::Payment::<name>` subroutine normally all
match: `Route authorizenet ...`, `MV_PAYMENT_MODE authorizenet`, and
`Vend::Payment::authorizenet`. The gateway also lands in
`$Vend::Session->{payment_mode}` for the order report to log.

Running more than one gateway at once is just more than one route. Point
`[charge]` at whichever route you want, or drive `MV_PAYMENT_MODE` from a form
so the shopper's payment choice selects the gateway. strap does exactly this: a
separate `MV_ONLINE_CHECK_MODE` route handles ACH checks while
`MV_PAYMENT_MODE` handles cards, and `log_transaction` charges through whichever
one the chosen order profile implies.

## Amount, currency, and order id

You rarely pass an amount. When `amount` is omitted, `charge` uses
`Vend::Interpolate::total_cost()` — the same order total the shopper saw. It is
then rounded to the `precision` option (default `2`) and formatted, and a
currency string is prepended, so a gateway receives an amount like
`usd 19.95`. The currency is, in order, the `currency` option
([MV_PAYMENT_CURRENCY](../variables/MV_PAYMENT_CURRENCY.md)), the active
[locale](internationalization.md)'s `currency_code`, or `usd`. A route may set
`penny_pricing 1` to multiply the amount by 100 for gateways that want cents as
an integer.

The **order id** the gateway sees comes from `gen_order_id()`: an explicit
`order_id` option if you passed one, otherwise a value drawn from the route's
`counter` file, otherwise a generated timestamp (`YYMMDDHHMMSS` plus the process
id). In a database-backed checkout you normally pass the order's own
transaction id so the gateway record and your `transactions` row share a key:

    [charge route="[var MV_PAYMENT_MODE]"
             amount="[scratch tmp_remaining]"
             order_id="[value mv_transaction_id]"]

## Form fields the gateway sees

Gateways expect cardholder and address fields under stable names. `map_actual()`
builds that hash from [`[value]`](../tags/value.md) space and the CGI values,
mapping the checkout form's fields to canonical names: `fname`/`lname` (and a
composed `name`), `address1`/`address2` (and a composed `address`), `city`,
`state`, `zip`, `country`, `email`, `phone`, `mv_credit_card_number`,
`mv_credit_card_exp_month`/`_year`, `cvv2`, and the `check_*` fields for ACH.
Card expiration is normalized (stripped to digits, two-digit year) and a masked
`mv_credit_card_reference` like `41**1111` is derived from the number.

Billing-address handling has one wrinkle worth knowing. The `b_*` billing
fields are copied from the plain shipping fields **unless** the form actually
supplied a separate billing address; `MV_PAYMENT_BILLING_SET` and
`MV_PAYMENT_BILLING_INDICATOR` control which fields count as "a billing address
was entered." If a gateway needs a differently named field, the `remap` option
renames it without touching your form:

    Route  authorizenet  remap  "phone=phone_day  email=contact_email"

## Transaction types

The `transaction` option selects what the gateway does — authorize only,
authorize-and-capture (sale), settle a prior auth, void, or credit/return. It
is read through `charge_param('transaction')`; `map_actual` falls back to the
legacy default `mauthcapture` (a CyberCash-era name) when nothing sets it, and
most modern drivers treat that as "sale." Common values are `auth`, `sale`,
`settle`, `void`, and `return`/`credit`, but **the exact accepted set and the
exact behavior are per gateway** — a settle or void generally needs the
`order_id` and `auth_code` from the original sale, and some drivers spell the
types differently. Read the driver's [reference page](../payments/README.md)
before relying on a specific type. A two-step auth-then-capture, for example:

    [charge route=authorizenet transaction=auth amount=50.00]
    ...later, to capture...
    [charge route=authorizenet transaction=settle
             order_id="[value mv_order_id]" auth_code="[value mv_auth_code]"]

## Reading the result

`charge` stores the gateway's result hash in
`$Vend::Session->{payment_result}` (and pushes it onto
`$Vend::Session->{payment_stack}`, so several charges in one order each keep a
record). Success is judged by the `success_variable` key, default `MStatus`: a
value beginning with `success` is a success, anything else is a failure. On
failure `charge` copies the `error_variable` (default `MErrMsg`) into
`$Vend::Session->{payment_error}` and into
`$Vend::Session->{errors}{mv_credit_card_valid}` so the checkout can redisplay
the form with the decline reason, and it renames the gateway's `order-id` to
`invalid-order-id`. On success it sets `$Vend::Session->{payment_id}`.

Because the tag returns only the id, code that must branch reads the session.
The strap idiom captures the tag in a scratch flag and tests it:

    [tmp name="charge_succeed"][charge route="[var MV_PAYMENT_MODE]"
        amount="[scratch tmp_remaining]"
        order_id="[value mv_transaction_id]"][/tmp]
    [if scratch charge_succeed]
    [then]
        Real-time charge succeeded. ID=[data session payment_id]
    [/then]
    [else]
        Real-time charge FAILED. Reason: [data session payment_error]
    [/else]
    [/if]

Pass `hash=1` on the tag when you want the whole result hash back instead of the
id (`[charge route=... hash=1]` returns a reference in Perl callers). The
individual gateway pages document which extra keys (`pop.status`,
`pop.auth-code`, AVS/CVV codes, and so on) a given driver populates.

## Where the charge runs

`[charge]` can appear in three places in the order flow; all three ultimately
call `Vend::Payment::charge`.

**In an order profile, via `&charge`.** A profile line `&charge = mode` runs a
charge as part of validation and fails the check if it declines, so the shopper
never advances past a bad card. The [Carts and checkout](cart-and-checkout.md)
chapter covers profiles; the payment-relevant part is that the profile first
runs `&credit_card = standard keep ...` to validate and stage the card, then
charges.

**In an order route, via `payment_mode`.** A [Route](../config/Route.md) with a
`payment_mode` attribute charges when that route finalizes.

**In the order report template.** The most common production pattern, and what
strap ships: the `log_transaction` report interpolated by the `log` route
charges inside a [try](../tags/try.md)/[catch](../tags/catch.md) block so a
decline rolls the whole transaction back rather than writing a half-paid order:

    [try]
    ...
    [tmp name="charge_succeed"][charge route="[var MV_PAYMENT_MODE]"
        amount="[scratch tmp_remaining]" order_id="[value mv_transaction_id]"][/tmp]
    [if scratch charge_succeed]
    [then][set do_payment]1[/set][/then]
    [else][calc] die errmsg("charge failed: %s", $Session->{payment_error}); [/calc][/else]
    [/if]
    ...
    [/try]
    [catch error-scratch="mv_route_failed"]
        There was an error accepting payment: $ERROR$
    [/catch]

`dist/strap/etc/log_transaction` is the full worked example — it charges,
decrements inventory, and writes the `transactions` and `orderline` tables in
one transactional route. Because the `log` route participates in the cascade's
`transactions`, the card charge and the table writes commit together or not at
all.

## PCI-conscious handling of card data

Payment brings the one datum you most want to never mishandle: the primary
account number (PAN). Interchange's defaults help, but the responsibility is
yours.

- **Do not store the raw PAN.** The real-time charge path uses the number in
  memory for the gateway call and never needs it persisted. When you must keep
  card data (offline processing), Interchange PGP/GPG-encrypts it: the
  `&credit_card = standard` profile directive (`encrypt_standard_cc` in
  `lib/Vend/Order.pm`) assembles the card block into `mv_credit_card_info`,
  encrypted to your [EncryptKey](../config/EncryptKey.md) with
  [EncryptProgram](../config/EncryptProgram.md). The layout is set by
  [MV_CREDIT_CARD_INFO_TEMPLATE](../variables/MV_CREDIT_CARD_INFO_TEMPLATE.md).
  Only the masked `mv_credit_card_reference` (e.g. `41**1111`) is safe to store
  or display in the clear.
- **Encrypt the report too, where used.** A route's `encrypt` /
  `credit_card` attributes PGP-encrypt the mailed order report so a card block
  never travels or rests as plaintext.
- **Keep numbers out of logs.** Interchange scrubs card fields before writing a
  request to [GatewayLog](../payments/GatewayLog.md), and you should never add
  `mv_credit_card_number` to a debug log or an order table column.

Card handling, transport, and storage are a security topic in their own right;
[Security](security.md) collects the encryption directives, key management, and
the wider hardening checklist. Treat the notes here as pointers into it.

## Logging gateway traffic

Several drivers ([AuthorizeNet](../payments/AuthorizeNet.md),
[Cardsave](../payments/Cardsave.md), and others) can record every attempt —
scrubbed request, response, timing, and outcome — to a database table through
the shared [GatewayLog](../payments/GatewayLog.md) base class. It is opt-in per
route:

    Route  authorizenet  gwl_enabled  1

The `gwl_table` and `gwl_source` options pick the table and tag the handling
server. This is transaction bookkeeping, distinct from the
[debug log](logging-debugging.md); see the
[GatewayLog page](../payments/GatewayLog.md) for the row schema and the strap
`gateway_log` table.

## Testing without a gateway account

Develop the whole checkout offline with
[TestPayment](../payments/TestPayment.md), a driver that approves or declines
purely by the submitted card number and makes no network call:

    Require module Vend::Payment::TestPayment    # interchange.cfg
    Variable  MV_PAYMENT_MODE  testpayment        # catalog.cfg
    Route  testpayment  id  testid

Then drive the checkout with the module's fixed card numbers —
`4111111111111111` approves, `4111111111111129` declines, any other number
errors — to exercise the approved, declined, and error branches of your
report template. The [TestPayment page](../payments/TestPayment.md) lists every
card and documents an inverted-logic quirk on its `return` transaction path;
follow it rather than guessing, since that page is verified against the driver's
code.

`MV_PAYMENT_TEST` is separate: it flips a *real* gateway into its own
sandbox/test mode (`Route authorizenet test 1`), for when you have test
credentials and want to reach the gateway's test host. Interchange also carries
two legacy internal test hooks — a charge type of `internal_test` and a
`transaction` of `minivend_test` — that short-circuit to a canned success
without any gateway; TestPayment is the maintained way to do offline testing.

## The gateway drivers

Each supported gateway is a `Vend::Payment::<Name>` module with its own
reference page. Load one with `Require module Vend::Payment::<Name>` in
`interchange.cfg`, then configure its route. The full set in this tree:

- Card gateways: [AuthorizeNet](../payments/AuthorizeNet.md),
  [Braintree](../payments/Braintree.md),
  [PayflowPro](../payments/PayflowPro.md),
  [CyberSource](../payments/CyberSource.md), [ICS](../payments/ICS.md),
  [Cardsave](../payments/Cardsave.md), [Ezic](../payments/Ezic.md),
  [Getitcard](../payments/Getitcard.md), [HSBC](../payments/HSBC.md),
  [iTransact](../payments/iTransact.md), [Linkpoint](../payments/Linkpoint.md),
  [MCVE](../payments/MCVE.md), [Merchantware](../payments/Merchantware.md),
  [NetBilling](../payments/NetBilling.md), [PRI](../payments/PRI.md),
  [Protx2](../payments/Protx2.md), [PSiGate](../payments/PSiGate.md),
  [Sage](../payments/Sage.md), [SagePay](../payments/SagePay.md),
  [TCLink](../payments/TCLink.md), [Worldpay](../payments/Worldpay.md),
  [EFSNet](../payments/EFSNet.md),
  [BusinessOnlinePayment](../payments/BusinessOnlinePayment.md).
- Wallet / redirect: [PaypalExpress](../payments/PaypalExpress.md).
- Development: [TestPayment](../payments/TestPayment.md).
- Shared infrastructure, not a gateway you select:
  [GatewayLog](../payments/GatewayLog.md).

Several of these pages document real behavior that differs from a driver's own
POD or from historic manuals — for example the inverted `return` branch in
TestPayment. Where a per-gateway page and this chapter's general model seem to
disagree for a specific gateway, the per-gateway page is right: it was verified
against that module's code.

You can also plug in a gateway that has no bundled driver by defining a
[GlobalSub](../config/GlobalSub.md) whose name matches the route/gateway;
`charge` dispatches to a matching `GlobalSub` before it looks for a
`Vend::Payment::*` routine. The legacy `custom <subname>` charge type does the
same for MiniVend-era code.

## See also

- [Carts and checkout](cart-and-checkout.md) — order profiles, `&credit_card`,
  routes, and the `log_transaction` report that calls `[charge]`
- [charge](../tags/charge.md) — the tag reference
- [MV_PAYMENT_MODE](../variables/MV_PAYMENT_MODE.md),
  [MV_PAYMENT_ID](../variables/MV_PAYMENT_ID.md),
  [MV_PAYMENT_SECRET](../variables/MV_PAYMENT_SECRET.md),
  [MV_PAYMENT_CURRENCY](../variables/MV_PAYMENT_CURRENCY.md),
  [MV_PAYMENT_PRECISION](../variables/MV_PAYMENT_PRECISION.md),
  [MV_PAYMENT_TEST](../variables/MV_PAYMENT_TEST.md) — the payment variables
- [The payments reference](../payments/README.md) — every gateway driver
- [GatewayLog](../payments/GatewayLog.md) — per-transaction database logging
- [TestPayment](../payments/TestPayment.md) — offline development gateway
- [Security](security.md) — card encryption, key management, hardening
- [Route](../config/Route.md), [Variable](../config/Variable.md),
  [EncryptKey](../config/EncryptKey.md),
  [EncryptProgram](../config/EncryptProgram.md) — the directive reference
- [Pricing](pricing.md), [Shipping](shipping.md), [Taxes](taxes.md) — how the
  order total the charge uses is built
