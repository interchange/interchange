# row

Lay body text out into fixed-width columns for plain-text output. Give a total
width and one or more `[col]` blocks, and `[row]` pads, aligns, and wraps each
column into aligned monospace columns — the tool for text email bodies,
receipts, and other non-HTML reports.

## Syntax

    [row WIDTH]
    [col WIDTH]left column[/col]
    [col WIDTH align=right]right column[/col]
    [/row]

Container tag (has an end tag). Its body is interpolated first, then scanned for
`[col]...[/col]` (or `[column]...[/column]`) blocks; each becomes one column of
the output. Text outside `[col]` blocks is ignored.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `width`   | none    | Total character width available for the row (positional). |

Positional order: `width`.

The tag declares `Interpolate`, so ITL inside the body (including inside each
`[col]`) is expanded before the columns are formatted.

### `[col]` options

Each column is configured by attributes on its `[col]` tag:

| Option    | Default | Description |
|-----------|---------|-------------|
| `width`   | `0`     | Column width in characters (positional; a bare number is taken as `width`). |
| `align`   | `left`  | `left`, `right`, `none` (keep the text's own line breaks), or `input` (no wrap, for form fields). |
| `gutter`  | `2`     | Blank characters reserved to the right of the column. |
| `spacing` | `1`     | Line spacing; a value >1 inserts blank lines between wrapped lines. |
| `wrap`    | `1`     | Word-wrap text wider than the column; mutually exclusive with `html`. |
| `html`    | `0`     | Treat content as HTML (lengths ignore tags); disables `wrap`. |

The usable text width of a column is its `width` minus its `gutter`; a column
whose usable width falls below 1 renders `BAD_WIDTH`. If the columns' widths add
up to more than the row `width`, the row returns a "columns too wide" message.

## Description

`[row]` computes each `[col]`'s lines independently — wrapping or truncating to
the usable width and padding to the column width per its `align` — then stacks
the columns side by side, one output line per row of the tallest column.
Trailing whitespace on the final column of each line is trimmed. The result is a
block of plain, space-padded text; it contains no HTML.

## Examples

Two headed columns in a 20-character row:

    [row 20]
    [col 10]Name[/col]
    [col 10]Qty[/col]
    [/row]

produces (the second column starts at character 11):

    Name      Qty

A right-aligned price column, driving each cell from ITL:

    [row 40]
    [col 24][item-field description][/col]
    [col 16 align=right][currency][item-price][/currency][/col]
    [/row]

## Notes

`[row]` is for fixed-width, monospace output; it does not build HTML tables. For
an HTML `<table>` from a list use [item-list](item-list.md) or
[html-table](html-table.md) with your own markup, and for an admin-style report
grid see [table-organize](table-organize.md).

## See also

- [html-table](html-table.md), [table-organize](table-organize.md),
  [item-list](item-list.md)
- Concepts: [email](../guides/email.md), [templating](../guides/templating.md)

## Source

Defined in `code/SystemTag/row.coretag` as an inline Routine (with helper subs
`tag_column` and `wrap`).
