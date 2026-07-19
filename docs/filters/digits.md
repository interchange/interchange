# digits

Removes every character that is not a digit (`0-9`).

## Syntax

    [filter digits]TEXT[/filter]
    [value name=field filter="digits"]

`digits` takes no arguments. It can be used anywhere a filter is
accepted: the [filter](../tags/filter.md) tag, the `filter=` attribute
of tags such as [value](../tags/value.md), and the `filter` setting of a
form widget.

## Description

The filter strips out every non-digit character, using the substitution
`s/\D+//g`. Letters, whitespace, punctuation (including any minus sign or
decimal point), and multibyte characters are all removed. Empty or
undefined input yields the empty string.

## Examples

    [filter digits]Only 2 digits should come out of this 1 line ;-)[/filter]

produces:

    21

To keep the value's decimal point, use [digits_dot](digits_dot.md); to
keep dashes (as in a part number or phone number), use
[digits_dash](digits_dash.md).

## See also

- [digits_dot](digits_dot.md)
- [digits_dash](digits_dash.md)
- [integer](integer.md)

## Source

Defined in `code/Filter/digits.filter`.
