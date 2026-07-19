# html-table

Turn delimited text (or an array) into HTML table rows and cells. Reach for it
when you have tab- or newline-delimited data and want the `<tr>`/`<td>`
markup generated for you.

## Syntax

    [html-table]
    col1<TAB>col2<TAB>col3
    r1c1<TAB>r1c2<TAB>r1c3
    [/html-table]

    [html-table columns="Name Price" th=1 td="align=right"]...[/html-table]

Container tag (has an end tag and processes its body). The generated markup is
not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute      | Default | Description |
|----------------|---------|-------------|
| `columns`      | none    | Whitespace-separated column heading names. Ignored when `th` is set. |
| `delimiter`    | tab (`\t`) | Field delimiter within a row of in-place body data. |
| `record_delim` | newline (`\n`) | Record (row) delimiter for in-place body data. |
| `th`           | none    | Extra attributes for the header `<th>` cells; when set, the first body row supplies the column names and `columns` is ignored. |
| `tr`           | none    | Extra attributes added to every `<tr>`. |
| `td`           | none    | Extra attributes added to every `<td>`. |
| `fr`           | none    | Extra attributes for the first data row; also causes that row to be emitted as a leading row. |
| `fc`           | none    | Extra attributes for the first column's `<td>` in each row. |

Positional order: none (all parameters are named).

## Description

`[html-table]` builds the rows and cells of an HTML table but **not** the
enclosing `<table>` element — you supply that yourself. This lets you set
`width`, `border`, CSS classes, and so on however you like.

By default the body is read as tab-delimited fields, one record per line. A
header row of `<th>` cells is emitted when you provide `columns` (or when `th`
is set, in which case the first body row becomes the headings). Empty cells
render as `&nbsp;`.

The `tr`, `td`, `th`, `fr`, and `fc` attributes inject extra attribute text
into the corresponding tags; for example `td="class='num'"` renders each cell
as `<td class='num'>`.

## Examples

Render a small table from in-place tab-delimited data:

    <table border="1">
    [html-table columns="Item Qty"]
    Widget	3
    Gadget	1
    [/html-table]
    </table>

produces (whitespace condensed):

    <table border="1">
    <tr><th><b>Item</b></th><th><b>Qty</b></th></tr>
    <tr><td>Widget</td><td>3</td></tr>
    <tr><td>Gadget</td><td>1</td></tr>
    </table>

Use the first body row as headings and style the first column and header:

    <table width="90%" border="1">
    [html-table fc="bgcolor='red'" fr="bgcolor='blue'" th="bgcolor='yellow'"]
    title1	title2	title3
    r1c1	r1c2	r1c3
    r2c1	r2c2	r2c3
    [/html-table]
    </table>

## Notes

Because the body responds to literal tabs and newlines, do not indent the
data rows — leading whitespace becomes part of the first cell. Separate
fields with exactly one delimiter; consecutive delimiters imply empty cells.

## See also

- [table-organize](table-organize.md)
- [loop](loop.md)
- [query](query.md)
- Concepts: [templating](../guides/templating.md)

## Source

Defined in `code/SystemTag/html_table.coretag`. Implemented by
`Vend::Interpolate::html_table`.
