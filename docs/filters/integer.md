# integer

Returns the integer value of the input by applying Perl's `int()`, truncating
toward zero.

## Syntax

    [filter integer]TEXT[/filter]
    [value name=field filter="integer"]

## Description

The filter returns `int($value)`. Perl's `int()` truncates toward zero (it does
not round): `12.9` becomes `12`, and `-12.9` becomes `-12`. A leading numeric
portion is used and the rest is ignored, so `904.82abc` yields `904`; a string
with no leading number yields `0`. Empty or undefined input yields `0`.

Because `int()` reads only the leading numeric run, pair integer with
[no_white](no_white.md) and [digits_dot](digits_dot.md) when the input may
contain surrounding text. To round instead of truncate, use
[round](round.md).

## Examples

Truncate a decimal:

    [filter integer]12.4[/filter]

produces:

    12

Strip whitespace, keep only digits and dots, then take the integer part:

    [filter op="no_white digits_dot integer"]Stock 904.82[/filter]

produces:

    904

## See also

- [round](round.md)
- [digits](digits.md)
- [digits_dot](digits_dot.md)
- [no_white](no_white.md)
- [commify](commify.md)

## Source

Defined in `code/Filter/integer.filter`.
