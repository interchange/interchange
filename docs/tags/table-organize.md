# table-organize

Reflow a flat series of `<td>` cells into an HTML table of a fixed number of
columns. Reach for `[table-organize]` when you have a list of items (from a
[loop](loop.md), search, or component) and want them laid out N-across in a
grid, with filler cells padding the last row.

## Syntax

    [table-organize cols=N]
    <td>...</td> <td>...</td> ...
    [/table-organize]

Container tag (has an end tag and processes its body). The body is interpolated
first (`Interpolate`), so tags inside it run before the cells are organized.

## Attributes

| Attribute   | Default              | Description                                                    |
|-------------|----------------------|---------------------------------------------------------------|
| `cols`      | `2`                  | Number of columns. Alias: `columns`.                          |
| `rows`      |                      | Number of rows; implies `table` and splits output into multiple tables. |
| `columnize` |                      | Fill columns first ("newspaper" order) instead of rows.       |
| `min_rows`  |                      | Reduce `cols` until at least this many rows would be produced. |
| `limit`     |                      | Maximum number of cells to use; extras are dropped silently.  |
| `table`     |                      | If set, wrap output in `<table ATTR>...</table>` with these attributes. |
| `caption`   |                      | `<caption>` text; may be an array, alternating per table.     |
| `tr`        |                      | Attributes for each `<tr>`; may be an array, alternating per row. |
| `td`        |                      | Attributes for each `<td>`; may be an array, one per column.  |
| `pretty`    |                      | Insert newlines and tabs to indent the generated HTML.        |
| `filler`    | `&nbsp;`             | Content placed in the padding cells of a short last row.      |
| `font`      |                      | Attributes for a `<font>` wrapper inside each cell.           |
| `joiner`    | `\n\t\t` when `pretty`, else empty | String used to join cells within a row.         |
| `embed`     |                      | Distinguish outer cells from nested tables (see below).       |
| `cells`     |                      | Supply the cells directly as an array reference (Perl).       |

Positional order: `cols`. Alias: `columns` for `cols`. The tag also accepts
arbitrary named attributes (`addAttr`).

## Description

`[table-organize]` scans the interpolated body for `<td>...</td>` cells,
preserving whatever precedes the first cell and follows the last one, then
emits them `cols` per row. When the cell count is not a multiple of `cols`, the
short final row is padded with cells containing `filler`.

`tr`, `td`, and `caption` may each be given as indexed arrays
(`tr.0=...`, `tr.1=...`). `tr` and `caption` alternate by modulus; `td` should
have exactly one entry per column (extra entries are ignored, and if there are
fewer than `cols` the attribute is dropped).

With `columnize=1`, cells are distributed down columns before across rows,
producing a "rotated" grid. `rows=N` limits each table to N rows and starts a
fresh `<table>` for the overflow. `min_rows` prevents an ugly wide-but-shallow
grid on small result sets by shrinking `cols` until the minimum row count is
met.

### Embedding tables inside cells

If a cell itself contains a `<table>`, `[table-organize]` cannot tell the outer
cells from the nested ones. Resolve this with `embed`: use lowercase `<td>` for
the cells to organize and set `embed=lc`, or use uppercase `<TD>` for them and
set `embed` to any other true value (`embed=uc`). Nested cells then use the
opposite case and are left intact.

## Examples

Lay a loop of values out three across, with alternating row colors and
per-column alignment:

    [table-organize cols=3 pretty=1
       tr.0='bgcolor="#EEEEEE"' tr.1='bgcolor="#FFFFFF"'
       td.0='align=right' td.1='align=center' td.2='align=left']
    [loop list="1 2 3 1a 2a 3a 1b"] <td>[loop-code]</td> [/loop]
    [/table-organize]

The seven cells fill three rows; the last row is padded to three columns with
`&nbsp;` filler.

A Bootstrap-styled product grid, as used by the strap demo's upsell component:

    [table-organize embed=1 pretty=1 cols="[control cols 2]"]
    [item-list]
      <td>[page href="[item-code]"][item-field description]</a></td>
    [/item-list]
    [/table-organize]

## See also

- [loop](loop.md) — commonly supplies the cells
- [component](component.md) — strap components that use this tag for grids
- The [templating guide](../guides/templating.md)

## Source

Defined in `code/UserTag/table_organize.tag` as an inline `Routine`.
