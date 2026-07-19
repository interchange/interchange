# large

Wraps the input in a `<large>` element.

## Syntax

    [filter large]TEXT[/filter]
    [value name=field filter="large"]

## Description

The filter returns the input surrounded by `<large>` and `</large>`. It does no
escaping and adds nothing else; empty input yields `<large></large>`. The
filter is marked `Visibility private`.

Note that `<large>` is not a standard HTML element (unlike `<small>`), so most
browsers will not render it with any special styling. This filter exists as the
counterpart to [small](small.md); for enlarging text in modern markup, prefer
CSS.

## Examples

    [filter large]Big news[/filter]

produces:

    <large>Big news</large>

## See also

- [small](small.md)
- [italics](italics.md)
- [bold](bold.md)
- [pre](pre.md)
- [tt](tt.md)

## Source

Defined in `code/Filter/large.filter`.
