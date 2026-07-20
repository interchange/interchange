# PSiGate (Vend::Payment::PSiGate)

Processes credit card sales, pre-authorizations, post-authorizations, and
voids through PSiGate's "HTML Posting Direct Response" HTTPS API.

## Prerequisites

One of:

- `Net::SSLeay`
- `LWP::UserAgent` and `Crypt::SSLeay`

Only one of the two combinations needs to be installed and working.

## Configuration

    Require module Vend::Payment::PSiGate        # interchange.cfg
    Variable MV_PAYMENT_MODE  psigate             # catalog.cfg
    Route  psigate  id  YourPSiGateMerchantID

The module defines a `psigate` routine (lowercase), so the gateway/mode
name must be `psigate`.

| Option | Default | Meaning |
| --- | --- | --- |
| `id` | none | Your PSiGate merchant ID. Also settable as `MV_PAYMENT_ID`. Required; the charge fails with "No account id" if missing. |
| `transaction` | `sale` | See [Transaction types](#transaction-types). |
| `remap` | none | Remaps form field names to the ones PSiGate expects; see the shared payment-settings behavior in [Payment processing concepts](../guides/payments.md). |
| `precision` | 2 | Decimal places for the amount (not read through `charge_param`, so it is call-option only, no `Route`/`MV_PAYMENT_PRECISION` fallback). |

## Transaction types

| Interchange | PSiGate code | Meaning |
| --- | --- | --- |
| `auth` | `1` | PreAuth |
| `sale` | `0` | Sale |
| `settle` | `2` | PostAuth |
| `void` | `9` | Void |

Any other value returns a hard failure ("Invalid transaction type").

## Testing

The module's own documentation describes a `test` option (`Route
psigate test TRUE` / `MV_PAYMENT_TEST` / `[charge mode=psigate
test=TRUE]`) that is supposed to set PSiGate's `x_Test_Request` query
parameter. **The current code does not implement this** -- no `test`
value is read anywhere in the `psigate` routine, and no
`x_Test_Request` field is ever sent. To test error handling, use
PSiGate's documented test card number `4111 1111 1111 1111` against a
live PSiGate test-mode account configured on PSiGate's side instead of
relying on this module to flip a test flag.

## Examples

Minimal `catalog.cfg` fragment:

    Variable MV_PAYMENT_MODE  psigate
    Route  psigate  id  YourPSiGateMerchantID

    [charge route="psigate"]

Explicit transaction type:

    [charge route="psigate" transaction="settle"]

## Notes

The module's documentation also describes a `referer` option (`Route
psigate referer ...` / `MV_PAYMENT_REFERER`) used to set the HTTP
`Referer` header PSiGate checks against your account settings. The code
that would read this option is present but commented out, so `referer`
is always empty and the `Referer` header PSiGate receives is blank
regardless of any value you configure. If your PSiGate account requires
a matching referer, this module cannot currently satisfy that check.

## See also

[Payment processing concepts](../guides/payments.md).

## Source

`lib/Vend/Payment/PSiGate.pm`, subroutine `psigate` in package
`Vend::Payment` (has its own POD).
