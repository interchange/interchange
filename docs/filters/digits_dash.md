# digits_dash

Removes every character that is not a digit (`0-9`) or a dash (`-`).

## Syntax

    [filter digits_dash]TEXT[/filter]
    [value name=field filter="digits_dash"]

`digits_dash` takes no arguments. It can be used anywhere a filter is
accepted: the [filter](../tags/filter.md) tag, the `filter=` attribute
of tags such as [value](../tags/value.md), and the `filter` setting of a
form widget.

## Description

The filter strips out any run of characters that are neither digits nor
dashes, using the substitution `s/[^\d-]+//g`. It is useful for cleaning
up part numbers, phone numbers, and similar dash-delimited codes. Empty
or undefined input yields the empty string.

## Examples

    [filter digits_dash]Digits-dash code is: 90901212-3124[/filter]

produces:

    -90901212-3124

Note the leading dash: the dash in the word `Digits-dash` is kept, since
the filter only removes characters, it does not understand word
boundaries.

## See also

- [digits](digits.md)
- [digits_dot](digits_dot.md)

## Source

Defined in `code/Filter/digits_dash.filter`.
