# checkbox

Returns the value unchanged if it has any length, and the empty string
otherwise.

## Syntax

    [filter checkbox]TEXT[/filter]
    [value name=field filter="checkbox"]

`checkbox` takes no arguments. It can be used anywhere a filter is
accepted: the [filter](../tags/filter.md) tag, the `filter=` attribute
of tags such as [value](../tags/value.md), and the `filter` setting of a
form widget.

## Description

The filter tests `length($value)`: if the value has one or more
characters it is returned as-is, otherwise the empty string is returned.
Undefined input becomes the empty string.

The name reflects its typical use: an HTML checkbox submits its value only
when checked, and submits nothing when unchecked. Running the incoming
value through `checkbox` normalizes an unchecked (undefined) submission to
a definite empty string, which is convenient when storing the result.

Note that a value of `0` has length 1, so `checkbox` returns it unchanged;
the filter distinguishes empty from non-empty, not true from false.

## Examples

    [filter checkbox]on[/filter]

produces:

    on

An empty body:

    [filter checkbox][/filter]

produces the empty string.

## See also

- [checkbox](../widgets/checkbox.md) widget
- [yesno](yesno.md)
- [value](value.md)

## Source

Defined in `code/Filter/checkbox.filter`.
