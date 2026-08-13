# compress_space

Trims leading and trailing whitespace and collapses every internal run of
whitespace to a single space.

## Syntax

    [filter compress_space]TEXT[/filter]
    [value name=field filter="compress_space"]

`compress_space` takes no arguments. It can be used anywhere a filter is
accepted: the [filter](../tags/filter.md) tag, the `filter=` attribute
of tags such as [value](../tags/value.md), and the `filter` setting of a
form widget.

## Description

The filter performs three substitutions in order: it removes trailing
whitespace (`s/\s+$//g`), removes leading whitespace (`s/^\s+//g`), and
replaces every remaining run of whitespace with a single space
(`s/\s+/ /g`). Whitespace includes spaces, tabs, and newlines, so
multi-line input is flattened to one line with single-space separators.
Empty or undefined input yields the empty string.

## Examples

    [filter compress_space]   LEADING   Hello,  World!   TRAILING  [/filter]

produces:

    LEADING Hello, World! TRAILING

## See also

- [strip](strip.md)
- [no_white](no_white.md)
- [oneline](oneline.md)

## Source

Defined in `code/Filter/compress_space.filter`.
