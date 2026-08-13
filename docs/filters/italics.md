# italics

Wraps the input in an HTML `<i>` (italic) element.

## Syntax

    [filter italics]TEXT[/filter]
    [value name=field filter="italics"]

## Description

The filter returns the input surrounded by `<i>` and `</i>`. It performs no
escaping of the input and adds nothing else; empty input yields `<i></i>`. The
filter is marked `Visibility private`, but it works anywhere a filter is
accepted.

## Examples

    [filter italics]Star Trek[/filter]

produces:

    <i>Star Trek</i>

## See also

- [bold](bold.md)
- [small](small.md)
- [large](large.md)
- [pre](pre.md)
- [tt](tt.md)
- [strikeout](strikeout.md)

## Source

Defined in `code/Filter/italics.filter`.
