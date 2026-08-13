# isbn

Verifies the check digit of an ISBN-10 or ISBN-13 book number, optionally
restricted to one format.

## Syntax

    FIELD=isbn [10|13] [message]

Used as the check name in an order-profile line. There is no shipped strap
demo profile using `isbn`; a minimal example against a field collecting a
book code:

    isbn_field=isbn Not a valid ISBN code.

## Description

The value has all non-digit, non-`X`/`x` characters stripped, then:

- If exactly 10 digits (the last may be `X`/`x`, the ISBN-10 check
  character worth 10) remain, the check performs the ISBN-10 weighted-sum
  test (weights 10 down to 1, sum divisible by 11).
- If exactly 13 digits remain, it performs the ISBN-13/EAN-13 test (alternating
  weights 1 and 3, computed check digit compared to the last digit).
- Any other digit count fails.

An optional leading `10` or `13` before the message restricts which format
is accepted -- `isbn 13 ...` fails a 10-digit value outright (and vice
versa) instead of validating it against the other format.

## Examples

Accept either ISBN-10 or ISBN-13:

    isbn_field=isbn "Not a valid ISBN code"

Accept only ISBN-13:

    isbn_field=isbn 13 "Not a valid ISBN-13 code"

Accept only ISBN-10:

    isbn_field=isbn 10 "Not a valid ISBN-10 code"

## Notes

Verified against `code/OrderCheck/isbn.oc`: after the optional `10`/`13`
prefix is stripped off, the remaining text of the argument (the intended
custom `message`) is never read again -- every failure path returns one of
three hard-coded messages (`'VALUE' not a valid isbn number`, `... isbn-10
number`, `... isbn-13 number`). A custom message written after `isbn` (or
after `isbn 13`/`isbn 10`) in a profile line is accepted syntactically but
has no effect on the text shown to the shopper. This contradicts historic
documentation, which shows custom messages working for this check; the
code is authoritative here.

## See also

[regex](regex.md), [error](../tags/error.md),
[OrderProfile](../config/OrderProfile.md),
the [cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Defined in `code/OrderCheck/isbn.oc`. The routine takes
`($ref, $var, $val, $msg)`, strips the optional `10`/`13` selector from
`$msg`, and performs the ISBN-10 or ISBN-13 checksum on the digit-only
value.
