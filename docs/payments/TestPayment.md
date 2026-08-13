# Test Payment (Vend::Payment::TestPayment)

An offline, no-network payment module for developing and testing
checkout flows. It approves or declines a charge purely by looking at
the credit card number you submit, so a catalog can be tested end to end
without a real payment gateway account. It is call-compatible with the
other Interchange payment modules, so switching to a real gateway later
is normally just a configuration change.

## Prerequisites

None. The module makes no network connections.

## Configuration

    Require module Vend::Payment::TestPayment    # interchange.cfg
    Variable MV_PAYMENT_MODE  testpayment         # catalog.cfg
    Route  testpayment  id  testid

The module defines a `testpayment` routine (lowercase), so the
gateway/mode name must be `testpayment`.

| Option | Default | Meaning |
| --- | --- | --- |
| `id` | none | Any value you like. Also settable as `MV_PAYMENT_ID`. Required; the charge fails with "No account id" if missing. |
| `secret` | none | Any value you like. Also settable as `MV_PAYMENT_SECRET`. Not actually used for any check. |
| `transaction` | `sale` | Accepted for call compatibility (`auth`, `return`, `reverse`, `sale`, `settle`, `void`), but only `settle*`, `void`, and `return` change behavior; anything else (including `sale`) falls through to the card-number check below. |
| `remap` | none | Remaps form field names to the ones this module expects; see the shared payment-settings behavior in [Payment processing concepts](../guides/payments.md). |
| `log` | unset | If true, writes an `errmsg`-formatted line for every charge attempt to the error log. |
| `logfile` | catalog's `ErrorFile` | Where the `log` line is written, if `log` is enabled. |

## Transaction types

For a `transaction` value starting with `settle`, or equal to `void`, the
module requires `order_id` and `auth_code` to be supplied as call
options (e.g. from a prior successful sale); success is reported only
when both are present:

    [charge route="testpayment" transaction="settle" order_id="123" auth_code="test_auth_code"]

For `transaction=return`, the module requires `order_id` -- but see
[Notes](#notes) about `auth_code` on this path.

For any other `transaction` value (including the default, `sale`), the
result is decided entirely from the submitted card number:

- `4111111111111111`, `6011333333333333` (Discover), `5454545454545454`
  (MasterCard), or `341111111111111` (Amex) -- approved, with
  `pop.auth-code` set to `test_auth_code`.
- `4111111111111129` -- declined ("Payment declined by the card
  issuer").
- Any other number -- declined ("Invalid test card number").

## Testing

This module *is* the test tool -- there is no separate sandbox mode.
Drive your checkout with the card numbers above to exercise the
approved, declined, and error paths, then inspect the result:

    <XMP>
    [calc]
        my $string = $Tag->uneval( { ref => $Session->{payment_result} });
        $string =~ s/{/{\n/;
        $string =~ s/,/,\n/g;
        return $string;
    [/calc]
    </XMP>

## Examples

Minimal `catalog.cfg` fragment using the strap demo:

    Variable MV_PAYMENT_MODE  testpayment
    Route  testpayment  id  testid

    [charge route="testpayment"]

Forcing a decline to test error handling on a checkout page:

    [charge route="testpayment"]
    <!-- submit mv_credit_card_number = 4111111111111129 to see the decline path -->

Logging every attempt for debugging:

    Route  testpayment  log      1
    Route  testpayment  logfile  logs/testpayment.log

## Notes

The `return` branch's logic looks inverted compared to `settle`/`void`:
where `settle` and `void` succeed only when `auth_code` **is** supplied,
`return` fails with "Need auth-code" when `auth_code` **is** supplied,
and only succeeds when it is absent. If you are scripting a credit/
return test against this module, omit `auth_code` from the call.

## See also

[Payment processing concepts](../guides/payments.md).

## Source

`lib/Vend/Payment/TestPayment.pm`, subroutine `testpayment` in package
`Vend::Payment` (has its own POD).
