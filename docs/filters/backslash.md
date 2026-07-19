# backslash

Removes every backslash (`\`) character from the value.

## Syntax

    [filter backslash]TEXT[/filter]
    [value name=field filter="backslash"]

`backslash` takes no arguments. It can be used anywhere a filter is
accepted: the [filter](../tags/filter.md) tag, the `filter=` attribute
of tags such as [value](../tags/value.md), and the `filter` setting of a
form widget.

## Description

The filter deletes all backslashes, using the substitution `s/\\+//g`.
Runs of consecutive backslashes are removed in a single pass. No other
characters are affected. Empty or undefined input yields the empty
string.

## Examples

    [filter backslash]a\b\\c\\\d[/filter]

produces:

    abcd

## See also

- [dbi_quote](dbi_quote.md)
- [sql](sql.md)

## Source

Defined in `code/Filter/backslash.filter`.
