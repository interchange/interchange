# MCVE (Vend::Payment::MCVE)

Charges cards through MCVE (Mainstreet Credit Verification Engine), an
in-house transaction-processing daemon, using the MCVE Perl client library.
Supports authorize and sale, with an optional two-step auth-then-sale model.

## Prerequisites

The MCVE Perl/C client library (from `http://www.mcve.com/`), providing the
`MCVE` package this module calls (`MCVE::MCVE_InitConn`,
`MCVE::MCVE_PreAuth`, and so on). An MCVE daemon/account already configured
with a username and password.

## Configuration

    Require module Vend::Payment::MCVE           # interchange.cfg

    Variable  MV_PAYMENT_MODE  mcve               # catalog.cfg
    Route  mcve  name    mcve_username
    Route  mcve  passwd  mcve_password

| Option | Default | Meaning |
|---|---|---|
| `name` | (required) | MCVE configuration username. Also settable as `MV_PAYMENT_NAME`. |
| `passwd` | (required) | MCVE configuration password. Also settable as `MV_PAYMENT_PASSWD`. |
| `host` | `sv1.carlc.com` | MCVE daemon host. Also settable as `MV_PAYMENT_HOST`. |
| `port` | `8333` | MCVE daemon port. Also settable as `MV_PAYMENT_PORT`. |
| `precision` | (unset; passed to rounding as-is) | Decimal places used when rounding the order total if no explicit amount is supplied. Also settable as `MV_PAYMENT_PRECISION`. |
| `counter` | `etc/mcve_order.counter` | File used to generate a sequential order ID when none is supplied. |
| `counter_start` | `100` | Starting value written to `counter` if the file doesn't exist yet. |
| `sale_on_auth` | `1` | If true and the transaction type is `sale`, immediately follows a successful pre-auth with `MCVE_PreAuthCompletion` to complete the sale. Also settable as `MV_PAYMENT_SALE_ON_AUTH`. |
| `no_sale_bad_avs` | `0` | If true, skips the sale-completion step when the AVS response is bad. Also settable as `MV_PAYMENT_NO_SALE_BAD_AVS`. |
| `no_sale_bad_cvv2` | `0` | If true, skips the sale-completion step when the CVV2 response is bad. Also settable as `MV_PAYMENT_NO_SALE_BAD_CVV2`. |
| `success_on_any` | `0` | If true, forces every transaction to report success regardless of the gateway's decline. Also settable as `MV_PAYMENT_SUCCESS_ON_ANY`. |

## Transaction types

Set with the `transaction` option, default `sale`:

| Interchange | MCVE mode |
|---|---|
| `auth`, `authorize`, `mauthonly`, `C` | `auth` |
| `sale`, `mauthcapture`, `S` | `sale` |
| `void`, `V` | `void` (mapped but not implemented by the routine) |
| `return`, `mauthreturn` | `return` (mapped but not implemented by the routine) |
| `delete` | `delete` (mapped but not implemented by the routine) |

Only `auth` and `sale` are actually processed by `mcve()`; the other
mapped values are recognized but have no corresponding code path in this
module.

## Testing

Try a sale with card number `4111 1111 1111 1111` and a valid expiration
date against your MCVE test configuration; it should be denied with the
reason in `[data session payment_error]`.

## Examples

Minimal configuration, capturing on successful auth:

    Require module Vend::Payment::MCVE

    Variable  MV_PAYMENT_MODE  mcve
    Route  mcve  name    mystorename
    Route  mcve  passwd  mypassword

Charging the order total through the route:

    [charge route="mcve"]

## See also

[Payment processing concepts](../guides/payments.md), [charge](../tags/charge.md),
[Route](../config/Route.md).

## Source

`lib/Vend/Payment/MCVE.pm` (module POD documents `name`,
`no_sale_bad_avs`, `sale_on_auth`, `success_on_any`, `transaction`, and
`counter`/`counter_start`; verified against the `mcve()` routine, which
reads `passwd`, `host`, and `port` directly via `charge_param` though the
POD does not spell them out individually).
