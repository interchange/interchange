# numeric_strict

Checks that a field's value is a plain, simply-formatted number -- an
optionally-signed integer or decimal, with no scientific notation, leading
whitespace, or special values.

## Syntax

    FIELD=numeric_strict [message]

Used as the check name in an order-profile line. There is no shipped strap
demo profile using `numeric_strict`; a minimal example against a price
override field:

    price_override=numeric_strict Please enter a plain number, e.g. 19.99.

## Description

The value passes only if it matches `\A-?\d+(?:\.\d+)?\z` in full: an
optional leading `-`, one or more digits, and an optional `.` followed by
one or more digits -- nothing else. Unlike [numeric](numeric.md), this
rejects a leading `+`, scientific notation (`1e10`), surrounding
whitespace, and a bare decimal point with no digits on one side. If no
custom `message` is given, the failure text is `not strict numeric`.

## Examples

Require a plain decimal price:

    price_override=numeric_strict

Require it with a custom message:

    weight=numeric_strict Weight must be a plain number like 2.5.

## See also

[numeric](numeric.md), [natural](natural.md), [error](../tags/error.md),
[OrderProfile](../config/OrderProfile.md),
the [cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Defined in `code/OrderCheck/numeric_strict.oc`. The routine takes
`($ref, $name, $value, $msg)` and tests `$value =~ /\A-?\d+(?:\.\d+)?\z/`.
