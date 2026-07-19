# round

Rounds a number to a fixed number of decimal places, in a
floating-point-safe way.

## Syntax

    [filter round]NUMBER[/filter]
    [filter round.DIGITS]NUMBER[/filter]
    [value name=field filter="round.DIGITS"]

The dotted `DIGITS` argument sets the number of decimal places; it defaults
to 2 (or to the current locale's `frac_digits` when a locale is active).

## Description

The filter rounds the value to `DIGITS` decimal places and always returns
that many digits after the decimal point, padding with zeros as needed.
Rounding is done digit-by-digit rather than through floating-point
arithmetic, which avoids the representation errors that can make a naive
round go the wrong way on values like `512.78955`.

A value that is not a plain (optionally signed) decimal number is returned
unchanged.

## Examples

With the default of two decimal places:

    [filter round]3.14159[/filter]

produces:

    3.14

    [filter round]10[/filter]

produces:

    10.00

Rounding to four places shows the floating-point-safe behavior:

    [filter round.4]512.78953[/filter]

produces:

    512.7895

    [filter round.4]512.78955[/filter]

produces:

    512.7896

    [filter round.4]512.78958[/filter]

produces:

    512.7896

## See also

[commify](commify.md), [currency](currency.md), [integer](integer.md)

## Source

Defined in `code/Filter/round.filter`; the rounding is performed by
`round_to_frac_digits` in `lib/Vend/Util.pm`.
