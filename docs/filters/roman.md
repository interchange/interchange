# roman

Converts an integer to its Roman numeral representation.

## Syntax

    [filter roman]NUMBER[/filter]
    [value name=field filter="roman"]

## Description

The filter removes every non-digit character from the value and converts
the resulting integer to uppercase Roman numerals. Thousands are written as
repeated `M`; the last three digits are rendered with the standard
units/tens/hundreds numerals (including the subtractive forms `IV`, `IX`,
`XL`, `XC`, `CD`, `CM`). If the value contains no digits, the filter returns
the empty string.

Because non-digits are stripped rather than rejected, a value like `2,005`
is treated as `2005`. There is no upper bound beyond what repeated `M`
characters can express, and zero (or an all-non-digit value) yields the
empty string.

## Examples

    [filter roman]2005[/filter]

produces:

    MMV

    [filter roman]49[/filter]

produces:

    XLIX

    [filter roman]1984[/filter]

produces:

    MCMLXXXIV

## See also

[integer](integer.md), [commify](commify.md)

## Source

Defined in `code/Filter/roman.filter`.
