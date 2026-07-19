# bold

Wraps the value in an HTML `<b>` (bold) element.

## Syntax

    [filter bold]TEXT[/filter]
    [value name=field filter="bold"]

`bold` takes no arguments. It can be used anywhere a filter is accepted:
the [filter](../tags/filter.md) tag, the `filter=` attribute of tags such
as [value](../tags/value.md), and the `filter` setting of a form widget.

## Description

The filter returns its input surrounded by `<b>` and `</b>`. It does not
escape or otherwise inspect the input; the value is inserted verbatim
between the tags. Even empty input produces the wrapping tags, so an empty
value becomes `<b></b>`.

## Examples

    [filter bold]To Boldly Go[/filter]

produces:

    <b>To Boldly Go</b>

## See also

- [italics](italics.md)
- [strikeout](strikeout.md)
- [small](small.md)
- [large](large.md)
- [pre](pre.md)
- [tt](tt.md)

## Source

Defined in `code/Filter/bold.filter`.
