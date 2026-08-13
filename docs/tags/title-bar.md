# title-bar

Wrap its body in a single-cell colored table to make a simple heading bar.
Reach for it for a quick colored title strip; note it emits legacy
`<table>`/`<font>` markup and predates CSS styling.

## Syntax

    [title-bar]Heading text[/title-bar]
    [title-bar width=600 size=5 color="#003366"]Heading[/title-bar]

Container tag. The body is interpolated (`Interpolate 1`), so ITL inside it is
processed.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `width`   | `500`   | Table width in pixels (positional 1). |
| `size`    | `6`     | `<font>` size for the text (positional 2). |
| `color`   | `@_HEADERBG@` or `#444444` | Background color of the bar (positional 3). |

Positional order: `width`, `size`, `color`.

## Description

The tag returns a one-row, one-cell HTML table whose cell background is
`color` and whose contents are the body wrapped in a `<font>` tag. The
background color defaults to the catalog Variable `HEADERBG` (falling back to
`#444444`); the text color comes from the Variable `HEADERTEXT` (falling back
to `WHITE`). If `color` is given without a leading `bgcolor=`, the tag adds it.

Because the body is interpolated, you can put other tags in the heading (a
[loc](loc.md) translation, a [value](value.md), and so on).

## Examples

A default title bar:

    [title-bar]Welcome to the store[/title-bar]

produces (whitespace collapsed):

    <TABLE CELLSPACING=0 CELLPADDING=6 WIDTH="500"><TR><TD VALIGN=CENTER
    BGCOLOR="#444444"><FONT COLOR="WHITE" SIZE="6">Welcome to the
    store</FONT></TD></TR></TABLE>

A narrower, custom-colored bar:

    [title-bar width=600 color="#003366"]Order confirmation[/title-bar]

## Notes

- This tag emits table-and-font markup from an earlier HTML era. For new
  templates, a styled heading element with CSS (see the [css](css.md) tag) is
  the modern equivalent.
- Set the `HEADERBG` and `HEADERTEXT` catalog Variables to theme every
  `[title-bar]` at once.

## See also

- [css](css.md) — CSS generation for modern styling
- [var](var.md) — read the `HEADERBG`/`HEADERTEXT` Variables
- The [templating guide](../guides/templating.md)

## Source

Defined in `code/UserTag/title_bar.tag` (inline `Routine`), registered as
`title-bar`.
