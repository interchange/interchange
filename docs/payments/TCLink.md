# TrustCommerce (Vend::Payment::TCLink)

Processes credit card pre-authorizations, sales, post-authorizations, and
credits through TrustCommerce's TCLink service. The Perl-to-gateway
transport is handled entirely by the CPAN `Net::TCLink` module; this
module only translates Interchange's payment data into the fields
`Net::TCLink` expects.

## Prerequisites

    Net::TCLink

Available from CPAN or from
<http://www.trustcommerce.com/tclink.html>. `Net::TCLink` does the actual
network communication; without it the module refuses to load.

## Configuration

    Require module Vend::Payment::TCLink         # interchange.cfg
    Variable MV_PAYMENT_MODE  trustcommerce       # catalog.cfg
    Route  trustcommerce  id      YourTrustCommerceID
    Route  trustcommerce  secret  YourTrustCommercePassword

The module defines a `trustcommerce` routine (not `tclink` or
`TCLink`), so the gateway/mode name must be `trustcommerce`.

| Option | Default | Meaning |
| --- | --- | --- |
| `id` | none | Your TrustCommerce customer ID. Also settable as the `TRUSTCOMMERCE_ID` variable. Required. |
| `secret` | none | Your TrustCommerce password. Also settable as the `TRUSTCOMMERCE_SECRET` variable. |
| `transaction` | `sale` | See [Transaction types](#transaction-types). Also settable as the `TRUSTCOMMERCE_ACTION` variable. |
| `avs` | `n` | Whether TrustCommerce performs AVS checking: `y` or `n`. Also settable as the `TRUSTCOMMERCE_AVS` variable. |
| `test` | unset | Sets TrustCommerce's `demo` flag to run the transaction against the demo processor. Also settable as the `TRUSTCOMMERCE_TEST` variable. |
| `remap` | none | Remaps form field names to the ones this module expects; see the shared payment-settings behavior in [Payment processing concepts](../guides/payments.md). |

Note that the `TRUSTCOMMERCE_*` variables above are read directly by the
module's own code, separately from -- and in addition to -- the generic
`MV_PAYMENT_ID`/`MV_PAYMENT_SECRET` fallback that `Route` options
normally get from the shared payment layer.

## Transaction types

| Interchange | TrustCommerce action | Meaning |
| --- | --- | --- |
| `auth`, `authorize`, `mauthonly` | `preauth` | Authorize only |
| `sale`, `mauthcapture` | `sale` | Authorize and capture |
| `settle`, `settle_prior` | `postauth` | Capture a prior `preauth` |
| `return` | `credit` | Credit/refund |

Any value not in this table is passed through to `Net::TCLink` verbatim.

## Testing

Set `test` (or `TRUSTCOMMERCE_TEST`) true to run against TrustCommerce's
demo processor. With demo mode on, use card number `4222 2222 2222 2222`
to exercise various TrustCommerce error responses, or `4111 1111 1111
1111` with a valid expiration date to get a denial (the reason appears
in `[data session payment_error]`).

## Examples

Minimal `catalog.cfg` fragment:

    Variable MV_PAYMENT_MODE  trustcommerce
    Route  trustcommerce  id      YourTrustCommerceID
    Route  trustcommerce  secret  YourTrustCommercePassword

    [charge route="trustcommerce"]

Testing with AVS enabled:

    Route  trustcommerce  test  TRUE
    Route  trustcommerce  avs   y

    [charge route="trustcommerce"]

## Notes

The module also reads a `referer` option (`$opt->{referer}` or
`charge_param('referer')`), but the value is never used afterward --
no header or query field is built from it. This is not documented in
the module's own POD either; it appears to be inherited, inert code
from another payment module's structure.

## See also

[Payment processing concepts](../guides/payments.md).

## Source

`lib/Vend/Payment/TCLink.pm`, subroutine `trustcommerce` in package
`Vend::Payment` (has its own POD).
