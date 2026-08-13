# Sage Payment Solutions (Vend::Payment::Sage)

Processes credit card sales, authorizations, prior-authorization
captures, voids, and credits through the Sage Payment Solutions (formerly
Vital Merchant Services) `eftBankcard.dll` HTTPS API.

## Prerequisites

One of:

- `Net::SSLeay`
- `LWP::UserAgent` and `Crypt::SSLeay`

Only one of the two combinations needs to be installed and working.

## Configuration

    Require module Vend::Payment::Sage           # interchange.cfg
    Variable MV_PAYMENT_MODE  sage                # catalog.cfg
    Route  sage  id      YourSageMerchantID
    Route  sage  secret  YourSageMerchantKey

The module defines a `sage` routine (lowercase), so the gateway/mode name
must be `sage`.

| Option | Default | Meaning |
| --- | --- | --- |
| `id` | none | Your 12-digit Sage merchant ID. Required; the charge fails with "No account id" if missing. |
| `secret` | none | Your 12-digit Sage merchant key. |
| `method` | `CC` | Payment method. `CC` (credit card) is the only value currently allowed. |
| `transaction` | `sale` | See [Transaction types](#transaction-types). |
| `precision` | 2 | Intended to set the decimal places for the amount, read into an option, but see [Notes](#notes) -- it currently has no effect on rounding. |
| `remap` | none | Remaps form field names to the ones this module expects; see the shared payment-settings behavior in [Payment processing concepts](../guides/payments.md). |
| `test` | unset | When true (see the shared `test` option set by the base payment layer), combined with `generate_error`, deliberately corrupts the request to exercise error handling. |
| `generate_error` | unset | Only consulted when `test` is also true. `number` sends an invalid card number; `date` sends an invalid expiration year. |

## Transaction types

| Interchange | Sage `T_code` | Meaning |
| --- | --- | --- |
| `sale`, `mauthcapture` | `01` | Sale (AUTH_CAPTURE) |
| `auth`, `authorize`, `mauthonly` | `02` | Authorization only |
| `PRIOR_AUTH_CAPTURE` | `03` | Force/prior-auth sale |
| `void` | `04` | Void |
| `return` | `06` | Credit |

Only the `CC` method allows any of these codes; any other transaction
name, or any method other than `CC`, is rejected with "Unknown Sage
method/transtype". Sage's `T_code 11` (prior-auth sale by reference) is
documented in the module's source comments but is not reachable through
any named transaction value.

## Testing

Set `test` true and `generate_error` to `number` or `date` to force a
declined test transaction without depending on a specific test card
number; there is no separate sandbox host, so this exercises the module
by intentionally sending bad data.

## Examples

Minimal `catalog.cfg` fragment:

    Variable MV_PAYMENT_MODE  sage
    Route  sage  id      YourSageMerchantID
    Route  sage  secret  YourSageMerchantKey

    [charge route="sage"]

Forcing a decline for testing:

    [charge route="sage" test=1 generate_error="number"]

## Notes

`precision` is read into `$opt->{precision}` but the amount is later
rounded with `Vend::Util::round_to_frac_digits($amount, $precision)`
using an unrelated, never-assigned `$precision` variable -- since
`Vend::Payment::Sage` does not `use strict`, this compiles but the
option you set has no effect; the amount is rounded to the catalog
locale's `frac_digits` (or 2) instead.

## See also

[Payment processing concepts](../guides/payments.md).

## Source

`lib/Vend/Payment/Sage.pm`, subroutine `sage` in package `Vend::Payment`
(has its own POD).
