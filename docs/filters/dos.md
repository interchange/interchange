# dos

Converts newlines to DOS/Windows form (`CR`+`LF`, that is `\r\n`).

## Syntax

    [filter dos]TEXT[/filter]
    [value name=field filter="dos"]

`dos` takes no arguments. It can be used anywhere a filter is accepted:
the [filter](../tags/filter.md) tag, the `filter=` attribute of tags such
as [value](../tags/value.md), and the `filter` setting of a form widget.

## Description

The filter normalizes line endings to the DOS convention with the
substitution `s/\r?\n/\r\n/g`: each Unix newline (`\n`), whether or not it
is already preceded by a carriage return, becomes a carriage-return /
line-feed pair (`\r\n`). Input already in DOS form is left unchanged.
Empty or undefined input yields the empty string.

Note that a bare Mac-style carriage return (`\r`) with no following
newline is not matched, so pure old-Mac line endings are not converted by
this filter.

## Examples

Given two lines separated by a Unix newline:

    [filter dos]line one
    line two[/filter]

the output is `line one\r\nline two` — the same text with the newline
replaced by a carriage-return / line-feed pair.

## See also

- [unix](unix.md)
- [mac](mac.md)

## Source

Defined in `code/Filter/dos.filter`.
