# Worldpay (Vend::Payment::Worldpay)

Redirects the customer to Worldpay's hosted "Select Junior"/WCC payment
page to take the card details off-site, then processes Worldpay's
server-to-server callback to convert a temporary basket into a completed
Interchange order. Unlike most Interchange payment modules, this one is
not a simple synchronous authorize call -- it drives a two-stage,
redirect-and-callback flow and writes directly to the `transactions` and
`orderline` tables.

## Prerequisites

One of:

- `Net::SSLeay`
- `LWP::UserAgent`, `Crypt::SSLeay`, `CGI`, `Encode`, and `Digest::MD5`

A recent `wget` is referenced in the module's own documentation, though
the shipped code does not call it directly the way the Protx/SagePay
modules do.

Using this module also requires catalog-side changes beyond `catalog.cfg`:
a callback page (commonly `pages/wpcallback.html`) that runs
`[charge route="worldpay" worldpayrequest="callback"]`, an order profile
entry, additional columns on the `transactions` table, and edits to
`etc/log_transaction` -- all spelled out in the module's own POD.

## Configuration

    Require module Vend::Payment::Worldpay        # interchange.cfg
    Variable MV_PAYMENT_MODE  worldpay             # catalog.cfg
    Route  worldpay  instid  YourWorldpayInstID
    Route  worldpay  md5pw   YourMD5Secret

The module defines a `worldpay` routine (lowercase), so the gateway/mode
name must be `worldpay`.

| Option | Default | Meaning |
| --- | --- | --- |
| `instid` | none | Your Worldpay installation ID. Required to build the redirect URL. |
| `md5pw` | none | Shared secret used to sign the redirect (`amount:instId:MC_affsubtotal:currency`, MD5 hex). **Required** -- the module `die`s immediately if this is not set. |
| `host` | `https://secure.wp3.rbsworldpay.com/wcc/purchase` | Live redirect URL. |
| `testhost` | `https://secure-test.wp3.rbsworldpay.com/wcc/purchase` | Redirect URL used instead of `host` whenever `testmode` is greater than `0`. |
| `testmode` | `0` | `0` for live; `100` (or any value greater than 0) sends the customer to `testhost` instead. |
| `currency` | `GBP` | ISO currency code sent to Worldpay. |
| `authmode` | `E` | Worldpay `authMode` field. Overridable from the page as `authmode`. |
| `authtype` | `WP PreAuthed` | Text recorded as the transaction's `txtype` on success; `-TEST` is appended automatically when `testmode` was active. |
| `callbackurl` | none | Your callback page, without the leading `https://`, for sites using per-catalog dynamic callback pages. |
| `callpw` | none | Password compared against Worldpay's callback to confirm it is genuine. |
| `fixcontact` | `0` | Set to `1` so the customer cannot edit the address details once at Worldpay. |
| `desc` | the generated cart ID | Text shown as the transaction description at Worldpay. |
| `tmporderprefix` | `Cart` | Prefix for the temporary order number used before the callback confirms payment (the module's own POD describes this prefix as `WPtmp`; the code's actual default is `Cart`). |
| `wpcounter` | `etc/username.counter` | Counter file supplying the numeric suffix for the temporary order number (the module's own POD describes the default as `etc/username`; the code's actual default includes the `.counter` suffix). |
| `ordernumber` | `etc/order.number` | Counter file used to generate the final Interchange order number once the callback confirms payment. |
| `reporttitle` | `0` | Set to `1` to include the Worldpay transaction ID and amount in the order-report email subject. |
| `update_status` | `pending` | Order status set on a successful callback (`-TEST` appended in test mode). |
| `dec_inventory` | `0` | Set to `1` to decrement the `inventory` table's `quantity` column directly from this module on a successful callback. |
| `oldic` | unset | Compatibility flag for Interchange versions older than 5.2, which set the order number differently. |
| `accid1` | none | Optional secondary Worldpay account ID, added to the redirect URL only if set. |

## Transaction types

There is no `transaction=` option here; the flow is driven by
`worldpayrequest`, which the module sets itself in most cases:

| `worldpayrequest` | When it runs | What happens |
| --- | --- | --- |
| `post` (default) | Checkout | Builds the signed redirect URL, logs a temporary basket under a `Cart`/`WPtmp`-prefixed order number, deletes any stale temporary baskets for the same username, and issues a 302 redirect to Worldpay. |
| `callback` | Worldpay calls your callback page | Verifies `callpw`, replaces the temporary order number with a final one, updates `transactions`/`orderline`, and re-runs the order via `Vend::Order::route_order("wp_final", ...)`. |

## Testing

Set `Route worldpay testmode 100` and place a test order; Worldpay's
hosted page lets you pick a card type and enter one of the test card
numbers listed in the module's own POD (for example, Mastercard
`5100080000000000`, Visa `4917610000000000`, Amex `370000200000000`).
Confirm the order appears in the `transactions` table and that the
confirmation emails go out after the callback runs.

## Examples

Minimal `catalog.cfg` fragment:

    Variable MV_PAYMENT_MODE  worldpay
    Route  worldpay  instid  YourWorldpayInstID
    Route  worldpay  md5pw   YourMD5Secret
    Route  worldpay  testmode  100

Checkout button that starts the redirect:

    [button
        mv_click=worldpay
        text="Place Order"
        hidetext=1
        form=checkout
       ]
       mv_order_profile=worldpay
       mv_order_route=log
       mv_todo=submit
    [/button]

## Notes

The `post` branch calls a subroutine named `dbconnectwp()` to get a
database handle for cleaning up stale temporary baskets, and the
`callback` branch's inventory-decrement path calls it again. **This
subroutine is not defined anywhere in this module, in `Vend::Payment`,
or elsewhere in this codebase.** As shipped, any call into this module
that reaches that code will fail with an "Undefined subroutine" error
unless your catalog supplies a `dbconnectwp` implementation itself (for
example as a `GlobalSub`). Budget time to write one, or to substitute
the standard `Vend::Data::dbref('transactions')->dbh()` pattern the
callback branch already uses elsewhere in the same module, before
relying on this module in production.

The module also reads an `allow_billing` Route option
(`charge_param('allow_billing')`) that is assigned to a variable and
then never used again.

## See also

[Payment processing concepts](../guides/payments.md).

## Source

`lib/Vend/Payment/Worldpay.pm`, subroutine `worldpay` in package
`Vend::Payment` (has its own POD).
