# options2line

Turns a comma-separated list into one item per line.

## Syntax

    [filter options2line]TEXT[/filter]
    [value name=field filter="options2line"]

## Description

The filter trims leading and trailing whitespace from the value, splits it
on commas (ignoring whitespace around each comma), and joins the pieces
with newlines, producing one item per line. Any `&#44;` entity in an item
is decoded back to a literal comma, so commas that were escaped to survive
comma-delimited storage are restored. An empty value is returned unchanged.

It is the inverse of [line2options](line2options.md), which collapses lines
back into a comma-separated list.

## Examples

    [filter options2line]one,two,three[/filter]

produces:

    one
    two
    three

Whitespace around each comma is absorbed:

    [filter options2line]red, green , blue[/filter]

produces:

    red
    green
    blue

## Notes

The filter accepts a dotted delimiter argument for symmetry with related
filters, but the current implementation ignores it and always splits on
commas.

## See also

[line2options](line2options.md), [option_format](option_format.md)

## Source

Defined in `code/Filter/options2line.filter`.
