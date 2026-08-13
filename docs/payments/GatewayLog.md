# GatewayLog (Vend::Payment::GatewayLog)

Not a payment gateway. `Vend::Payment::GatewayLog` is a shared base class
that several gateway drivers ([AuthorizeNet](AuthorizeNet.md),
[CyberSource](CyberSource.md), [Braintree](Braintree.md),
[PayflowPro](PayflowPro.md), [PaypalExpress](PaypalExpress.md))
inherit from to log every transaction attempt — request, response, timing,
and outcome — to a database table. You do not `Require` or select it as a
`gateway` yourself; it is used internally by the drivers that support it.

## Prerequisites

No external Perl modules beyond `Time::HiRes` (core). A table to log to —
the strap demo ships one named `gateway_log`
(`dist/strap/products/gateway_log.txt`, with per-engine schema in
`dist/strap/dbconf/*/gateway_log.*`).

## Configuration

GatewayLog itself is not `Require`d; it is loaded automatically when a
supporting driver is loaded. What you configure is that driver's own logging
options, all read the same way as any other payment option: `[charge]`
option, then `Route`, then `Variable MV_PAYMENT_*`.

    Route  authorizenet  gwl_enabled  1                # per-route
    Variable MV_PAYMENT_GWL_ENABLED 1                  # or globally

| Option        | Default                     | Meaning |
|---------------|------------------------------|---------|
| `gwl_enabled` | false                        | Turn on logging for this route/gateway. Logging is entirely opt-in. |
| `gwl_table`   | `gateway_log`                | Table the driver writes to. |
| `gwl_source`  | output of `` `hostname -s` `` | Value stored in the log row's `request_source` column; useful to identify which server handled the request behind a load balancer. |

A supporting driver constructs the object with these three options mapped to
`Enabled`, `LogTable`, and `Source`:

    my $gwl = Vend::Payment::AuthorizeNet->new({
        Enabled  => charge_param('gwl_enabled'),
        LogTable => charge_param('gwl_table'),
        Source   => charge_param('gwl_source'),
    });

It then calls `$gwl->request(\%scrubbed_request)`, brackets the gateway call
with `$gwl->start` / `$gwl->stop`, and calls `$gwl->response(\%response)`.
The actual database write happens automatically when the object is
destroyed (end of the enclosing scope), via a `log_it()` method that each
driver must override to map its own request/response fields onto the log
table's columns.

## Transaction types

Not applicable — GatewayLog does not talk to a payment processor. It only
records the outcome of whatever transaction the driving gateway module ran.

## Testing

Not applicable. To confirm logging is working, enable `gwl_enabled` for a
route that supports it (currently `authorizenet` or `cardsave`), run a test
transaction, and check the configured table for a new row.

## Examples

Enable logging for the `authorizenet` route to the default `gateway_log`
table:

    Route  authorizenet  gwl_enabled  1

Point logging at a differently-named table and tag the source explicitly
(e.g. in a multi-server setup):

    Route  authorizenet  gwl_enabled  1
    Route  authorizenet  gwl_table    authorizenet_log
    Route  authorizenet  gwl_source   web2

A logged `gateway_log` row (columns from `dist/strap/products/gateway_log.txt`)
includes `trans_type`, `processor`, `result_code`, `reason_code`,
`response_msg`, `request_id`, `order_number`, `request_duration`,
`request_date`, and the full `request`/`response` hashes serialized with
`::uneval()`, in addition to `email`, `amount`, `session_id`, `host_ip`,
`username`, and a `cart_md5` digest of the cart contents at the time of the
attempt.

## See also

[Payment processing concepts](../guides/payments.md), [AuthorizeNet](AuthorizeNet.md),
[Cardsave](Cardsave.md).

## Source

`lib/Vend/Payment/GatewayLog.pm` (has its own POD). Subclassed by gateway
drivers that override `log_it()`.
