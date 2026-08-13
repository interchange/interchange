# small

Wraps the value in an HTML `<small>...</small>` element.

## Syntax

    [filter small]TEXT[/filter]
    [value name=field filter="small"]

## Description

The filter prepends `<small>` and appends `</small>` to the value, so a
browser renders the text one size smaller than the surrounding copy. The
content is not modified or escaped.

## Examples

    [filter small]This text is smaller than usual.[/filter]

produces:

    <small>This text is smaller than usual.</small>

## See also

[pre](pre.md), [tt](tt.md), [large](large.md)

## Source

Defined in `code/Filter/small.filter`.
