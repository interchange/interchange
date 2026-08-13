# iTransact (Vend::Payment::iTransact)

Charges cards through iTransact's hosted order form (`ord.cgi`), redirecting
the transaction result back to Interchange. Implements a single sale-style
transaction; there is no separate auth/settle split.

## Prerequisites

`Net::SSLeay`, or `LWP::UserAgent` and `Crypt::SSLeay`. Only one of these
need be installed and working. An iTransact merchant account (vendor ID).

## Configuration

    Require module Vend::Payment::iTransact       # interchange.cfg

    Variable  MV_PAYMENT_MODE  itransact           # catalog.cfg
    Route  itransact  id  YouriTransactID

| Option | Default | Meaning |
|---|---|---|
| `id` | (required) | Your iTransact vendor ID. Also settable as `MV_PAYMENT_ID`. |
| `home_page` | `http://` + `SERVER_NAME` variable | Your site's home page, sent to iTransact as `home_page`. Also settable as `MV_PAYMENT_HOME_PAGE`. |
| `precision` | `2` | Decimal places used when rounding the order total if no explicit amount is supplied. |
| `submit_url` | `https://secure.itransact.com/cgi-bin/rc/ord.cgi` | iTransact's order-processing URL. Not exposed as a `Route`/`charge_param` option; set only via the tag/call `submit_url` attribute. |
| `generate_error` | (unset, test only) | When the call includes `test => 1`, set to `number` to force an invalid card number or to `date` to force an expired-card error, for testing decline handling. |

## Transaction types

There is only one transaction path: the module always posts a sale-style
order to iTransact's hosted form. The `transaction` option is not read.

## Testing

Enable test mode, run an order, and confirm it completes. Then switch to
live mode and try a sale with card number `4111 1111 1111 1111` and a valid
expiration date; iTransact should deny it, with the reason available in
`[data session payment_error]`.

## Examples

Minimal configuration:

    Require module Vend::Payment::iTransact

    Variable  MV_PAYMENT_MODE  itransact
    Route  itransact  id  YouriTransactID

Charging explicitly from a checkout page:

    [charge route="itransact" id="YouriTransactID"]

## See also

[Payment processing concepts](../guides/payments.md), [charge](../tags/charge.md),
[Route](../config/Route.md).

## Source

`lib/Vend/Payment/iTransact.pm` (module POD documents `id`, `home_page`, and
`remap`; verified against the `itransact()` routine, which also reads
`precision` and, in test mode, `generate_error`).
