# Payment Resources International (Vend::Payment::PRI)

Processes credit card sales through Payment Resources International (PRI)
using its `processCC.asp` HTTPS API. Only the `sale` transaction type is
implemented.

## Prerequisites

One of:

- `Net::SSLeay`
- `LWP::UserAgent` and `Crypt::SSLeay`

Either combination gives the module the HTTPS POST capability it needs;
only one has to be installed and working.

## Configuration

    Require module Vend::Payment::PRI          # interchange.cfg
    Variable MV_PAYMENT_MODE  PRI               # catalog.cfg
    Route  PRI  id            YourPRIID
    Route  PRI  regkey        YourPRIRegKey
    Route  PRI  test_id       YourPRITestID
    Route  PRI  test_regkey   YourPRITestRegKey
    Route  PRI  test_mode     0
    Route  PRI  refid_mode    2

`PRI` must be the gateway name Interchange looks up (the module defines a
`PRI` routine), so leave `gateway` unset if the Route/mode is also named
`PRI`, or set `Route mode gateway PRI` explicitly if you named the mode
something else.

| Option | Default | Meaning |
| --- | --- | --- |
| `id` | none | Production merchant ID. Falls back to the `MV_PAYMENT_ID` variable if not set via `Route`/call option. |
| `regkey` | none | Production registration key issued by PRI. |
| `test_id` | none | Test-account merchant ID, used when `test_mode` is 1, 2, or 3. |
| `test_regkey` | none | Test-account registration key. |
| `test_mode` | 0 | `0` live; `1` send real requests using the test account; `2` simulate a decline without contacting PRI; `3` simulate a success without contacting PRI. |
| `refid_mode` | (see meaning) | `1` increments the counter in `MV_ORDER_COUNTER_FILE` (default `etc/order.number`) and sends that; `2` sends the Interchange session ID (recommended); anything else sends a date-derived value (`DDDHHMMSS`). |
| `precision` | 2 | Decimal places for the amount. Falls back to `Route`/`MV_PAYMENT_PRECISION`. |
| `transaction` | `sale` | Only `sale` is implemented; see [Transaction types](#transaction-types). |
| `submit_url` | `https://webservices.primerchants.com/billing/TransactionCentral/processCC.asp?` | Override the PRI endpoint. |

`regkey`, `test_id`, `test_regkey`, `test_mode`, `refid_mode`, and
`submit_url` are read directly from the merged Route/call options and do
**not** fall back to any `MV_PAYMENT_*` variable -- only `id` and
`precision` go through that fallback chain. The module's own
documentation suggests setting `variable.txt` entries named `PRI_ID`,
`PRI_REGKEY`, `PRI_TEST_ID`, `PRI_TEST_REGKEY`, `PRI_TEST_MODE`, and
`PRI_REFID_MODE`; the code never reads variables by those names, so
those settings have no effect unless restated as `Route PRI ...` lines
(or per-call options).

## Transaction types

The module only builds a request when `transaction` is `sale` (the
default). Any other value falls through with no field data populated,
so PRI will reject the request; there is no support for `auth`,
`settle`, or `void`.

## Testing

Set `test_mode` to 3, then 2, then 1, then 0, confirming your catalog
handles each case:

- `3` -- forces a successful sale locally; nothing is sent to PRI.
- `2` -- forces a declined sale locally; nothing is sent to PRI.
- `1` -- sends the request to PRI using `test_id`/`test_regkey`. Submit
  invalid data to see how PRI reports errors.
- `0` -- live processing using `id`/`regkey`.

A response is treated as declined whenever PRI's `Auth` field is empty,
a single space, or contains "Declined".

## Examples

Minimal `catalog.cfg` fragment for a live PRI account:

    Variable  MV_PAYMENT_MODE  PRI
    Route  PRI  id       YourPRIID
    Route  PRI  regkey   YourPRIRegKey

    [charge route="PRI"]

Testing without contacting PRI at all:

    Route  PRI  test_mode  3

    [charge route="PRI" test_mode=3]

## See also

[Payment processing concepts](../guides/payments.md).

## Source

`lib/Vend/Payment/PRI.pm`, subroutine `PRI` in package `Vend::Payment`
(has its own POD).
