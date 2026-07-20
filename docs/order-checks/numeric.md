# numeric

Checks that a field's value looks like a number in any form Perl would
accept as one -- integers, decimals, signs, and scientific notation.

## Syntax

    FIELD=numeric [message]

Used as the check name in an order-profile line. There is no shipped strap
demo profile using `numeric`; a minimal example against a discount-percentage
field:

    discount_pct=numeric Please enter a number.

## Description

The value passes if `Scalar::Util::looks_like_number($value)` is true. This
accepts plain integers (`42`), decimals (`3.14`), signed values (`-5`,
`+2.5`), leading/trailing whitespace, scientific notation (`1e10`), and the
special strings `Inf`/`Infinity`/`NaN` (Perl's own numeric-string rules) --
a broader match than [numeric_strict](numeric_strict.md). If no custom
`message` is given, the failure text is `not numeric`.

## Examples

Require a numeric value:

    discount_pct=numeric

Require it with a custom message:

    weight=numeric Weight must be a number.

## See also

[numeric_strict](numeric_strict.md), [natural](natural.md),
[error](../tags/error.md), [OrderProfile](../config/OrderProfile.md),
the [cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Defined in `code/OrderCheck/numeric.oc`. The routine takes
`($ref, $name, $value, $msg)` and tests
`Scalar::Util::looks_like_number($value)`.
