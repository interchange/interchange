# space_to_nbsp

Converts literal spaces to the HTML non-breaking-space entity `&nbsp;`.

## Syntax

    [filter space_to_nbsp]TEXT[/filter]
    [filter space_to_nbsp.compress]TEXT[/filter]
    [value name=field filter="space_to_nbsp"]

## Description

The filter replaces space characters with `&nbsp;` so the text will not
word-wrap. By default every single space becomes one `&nbsp;`, which also
defeats the browser's usual collapsing of runs of whitespace -- each space
is preserved. Only the literal space character is converted; tabs and
newlines are left alone.

If any dotted argument is supplied (by convention `compress`), each *run* of
one or more spaces is collapsed to a single `&nbsp;` instead, so multiple
spaces render as one non-breaking space.

## Examples

By default each space becomes one entity:

    [filter space_to_nbsp]a  b[/filter]

produces:

    a&nbsp;&nbsp;b

With the compress argument, a run of spaces collapses to a single entity:

    [filter space_to_nbsp.compress]a  b[/filter]

produces:

    a&nbsp;b

## See also

[lspace_to_nbsp](lspace_to_nbsp.md), [space_to_null](space_to_null.md),
[compress_space](compress_space.md)

## Source

Defined in `code/Filter/space_to_nbsp.filter`.
