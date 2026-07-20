# length

Checks that a field's value is at least a minimum length, or falls within a
minimum-maximum length range.

## Syntax

    FIELD=length MIN[-MAX] [message]

Used as the check name in an order-profile line. The strap demo's password
reset page (`pages/query/pw_reset.html`) uses it with a minimum only:

    password=length 4 Password length less than minimum length of 4 characters.

and its checkout profile (`include/profiles/profiles.order`) uses the
`MIN-MAX` range form to pin a bank routing number to exactly 9 digits:

    check_routing=length 9-9 ABA bank route numbers are always 9 digits.

## Description

The argument starts with a required `MIN` and an optional `-MAX`; the
remaining text is the failure `message`. The value's `length()` is compared:
below `MIN` it fails with a "less than minimum length" message; above `MAX`
(when given) it fails with a "more than maximum length" message. A `MIN-MIN`
range, as in the routing-number example, effectively requires an exact
length.

If no custom `message` is given, the default messages are `FIELD length N
less than minimum length MIN.` and `FIELD length N more than maximum length
MAX.` respectively.

## Examples

Require at least 8 characters for a password:

    password=length 8 Please enter at least 8 characters for your password.

Constrain a username to between 6 and 32 characters:

    username=length 6-32 Size limits exceeded (6-32 characters).

Require an exact length, as the strap demo does for a bank routing number:

    check_routing=length 9-9 ABA bank route numbers are always 9 digits.

## See also

[regex](regex.md), [numeric](numeric.md), [error](../tags/error.md),
[OrderProfile](../config/OrderProfile.md),
the [cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Defined in `code/OrderCheck/length.oc`. The routine takes
`($ref, $name, $value, $msg)`, extracts `MIN[-MAX]` from the front of
`$msg` with a regex, and compares against `length($value)`.
