# colons_to_null

Replaces every pair of colons (`::`) with an ASCII NUL (`\0`) character.

## Syntax

    [filter colons_to_null]TEXT[/filter]
    [value name=field filter="colons_to_null"]

`colons_to_null` takes no arguments. It can be used anywhere a filter is
accepted: the [filter](../tags/filter.md) tag, the `filter=` attribute
of tags such as [value](../tags/value.md), and the `filter` setting of a
form widget.

## Description

The filter replaces each `::` sequence with a single NUL character
(`\0`), using the substitution `s/::/\0/g`. Interchange uses the NUL
character internally as a separator for multi-valued fields (for example
the several values of a multiple-select box), so this filter is the
inverse of [null_to_colons](null_to_colons.md): it turns the visible `::`
placeholder back into the internal separator. Empty or undefined input
yields the empty string.

Because the NUL it produces is a control character, the transformation is
generally not visible on screen; its effect matters when the value is
stored or split on NUL boundaries.

## Examples

    [filter colons_to_null]red::green::blue[/filter]

produces (with `.` marking each NUL character):

    red.green.blue

That is, `red\0green\0blue` — three values joined by the internal NUL
separator.

## See also

- [null_to_colons](null_to_colons.md)
- [null_to_comma](null_to_comma.md)
- [null_to_space](null_to_space.md)
- [space_to_null](space_to_null.md)

## Source

Defined in `code/Filter/colons_to_null.filter`.
