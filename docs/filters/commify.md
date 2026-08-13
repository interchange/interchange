# commify

Formats a number with comma thousands separators, first rounding it to a
fixed number of decimal places.

## Syntax

    [filter commify]NUMBER[/filter]
    [filter commify.PLACES]NUMBER[/filter]
    [value name=field filter="commify"]

The optional dotted argument `PLACES` sets the number of decimal places to
round to. When omitted it defaults to `2`.

## Description

The filter runs the value through `sprintf("%.<PLACES>f", ...)` and then
inserts a comma before every group of three digits in the integer part.
Because `PLACES` always has a value (defaulting to `2`), the number is
always rounded and reformatted to that many decimals — passing an integer
still gains a decimal fraction of zeroes.

The thousands separator is always a literal comma. It does **not** honor
the [Locale](../config/Locale.md) `mon_thousands_sep` setting, so
`commify` is for plain numeric display rather than locale-aware currency;
for locale-aware money formatting use [currency](currency.md).

## Examples

Default (two decimal places):

    [filter commify]1234567.5[/filter]

produces:

    1,234,567.50

Specifying the number of decimal places with the dotted argument:

    [filter commify.2]1234567890.123456[/filter]

produces:

    1,234,567,890.12

Zero decimal places, for a whole-number count:

    [filter commify.0]1000000[/filter]

produces:

    1,000,000

## See also

- [currency](currency.md)
- [round](round.md)
- [digits_dot](digits_dot.md)

## Source

Defined in `code/Filter/commify.filter`. The comma insertion is done by
`Vend::Util::commify` in `lib/Vend/Util.pm`.
