# digits_dot

Removes every character that is not a digit (`0-9`) or a dot (`.`).

## Syntax

    [filter digits_dot]TEXT[/filter]
    [value name=field filter="digits_dot"]

`digits_dot` takes no arguments. It can be used anywhere a filter is
accepted: the [filter](../tags/filter.md) tag, the `filter=` attribute
of tags such as [value](../tags/value.md), and the `filter` setting of a
form widget.

## Description

The filter strips out any run of characters that are neither digits nor
dots, using the substitution `s/[^\d.]+//g`. It is a common way to reduce
a price or numeric field to bare digits and a decimal point. Empty or
undefined input yields the empty string.

Only characters are removed; the filter does not validate that the result
is a well-formed number. Input such as `1.2.3` passes through unchanged,
and a currency string with a thousands separator such as `1,234.50` comes
out as `1234.50`.

## Examples

    [filter digits_dot]Price: $10.99[/filter]

produces:

    10.99

Stripping a formatted price to a bare number:

    [filter digits_dot]$1,234.50[/filter]

produces:

    1234.50

## See also

- [digits](digits.md)
- [digits_dash](digits_dash.md)
- [currency](currency.md)
- [commify](commify.md)

## Source

Defined in `code/Filter/digits_dot.filter`.
