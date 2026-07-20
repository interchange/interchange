# natural

Checks that a field's value is a natural number -- a whole number greater
than zero.

## Syntax

    FIELD=natural [message]

Used as the check name in an order-profile line. There is no shipped strap
demo profile using `natural`; a minimal example against a quantity field:

    quantity=natural Please enter a whole number greater than zero.

## Description

The value passes if it is true (non-zero, non-empty), greater than `0`, and
equal to its own integer conversion (`"$value" eq int($value)`) -- so
`3`, `42`, and `100` pass, while `0`, `-5`, `3.5`, and non-numeric strings
fail. If no custom `message` is given, the failure text is `no natural
number`.

## Examples

Require a plain positive whole number:

    quantity=natural

Require it with a custom message:

    quantity=natural Number is not a natural number.

## Notes

Historic documentation for this check notes that, prior to Interchange
5.5.2, the implementation incorrectly allowed zero and negative values to
pass. The current routine (`code/OrderCheck/natural.oc`) explicitly
requires `$value > 0`, so that issue is not present in the code as it
stands.

## See also

[numeric](numeric.md), [numeric_strict](numeric_strict.md),
[error](../tags/error.md), [OrderProfile](../config/OrderProfile.md),
the [cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Defined in `code/OrderCheck/natural.oc`. The routine takes
`($ref, $name, $value, $code)` and tests `$value and $value > 0 and
"$value" eq int($value)`.
