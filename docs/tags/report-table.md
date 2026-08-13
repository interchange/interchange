# report-table

Render the rows of an SQL query as an HTML table, with per-column formatting:
filters, form widgets, links, CSS classes, nested vertical and horizontal
subheaders, and virtual (computed) columns. Reach for it to build quick admin
reports and editable grids without hand-writing the row loop.

## Syntax

    <table>
    [report-table
        query="SELECT * FROM addresses"
        columns="address city state zip"
    ]
    </table>

Standalone tag (no end tag). It emits the `<tr>`/`<td>` rows only — you supply
the surrounding `<table>` element yourself.

## Attributes

| Attribute        | Default | Description |
|------------------|---------|-------------|
| `query`          |         | SQL SELECT run to produce the rows. |
| `columns`        |         | Space-separated column names to display, in order. |
| `column_defs`    |         | A Perl hash-of-hashrefs (as a string, `eval`-ed) giving per-column options. |
| `colheaders`     | `1`     | Emit the `<th>` header row. Set `0` to suppress it. |
| `title_horiz`    | `1`     | Prefix a horizontal subheader value with its title. |
| `reset_horiz`    | `1`     | Restart horizontal subheaders when a vertical header changes scope. |
| `row_toggle`     |         | Comma-separated `1`/`0` flags to include/skip individual result rows. |
| `row_hidden_id`  |         | A result column emitted as a hidden form field per row (key passing). |
| `no_results`     | `<tr><td colspan=N>No results</td></tr>` | Markup returned when the query is empty. |

This tag takes only named attributes. Per-column options live in
`column_defs`, keyed by column name:

| Column option | Description |
|---------------|-------------|
| `title`       | Column heading (defaults to the column name). |
| `header`      | `vert` or `horiz` — make the column a nested subheader. |
| `prefix` / `postfix` | Text placed just before/after the value. |
| `filter`      | Any Interchange [filter](../filters/) applied to the value. |
| `widget` + `widget_*` | Render the cell as a form [widget](../widgets/); `widget_cols`, `widget_rows`, etc. pass through. |
| `link` / `link_parm` / `link_key` | Wrap the cell in a [page](page.md) link, optionally passing a parameter from another result column. |
| `class` / `align` / `valign` / `width` | Cell presentation attributes. |
| `empty_cell`  | Substitute value when the cell is empty. |
| `dynamic`     | Fill from a computed value: `realrow`, `rowcount`, `linecount`, `parity`. |

## Description

The query runs against the `products` database connection (so its SQL may
select from any table that connection can reach), returning a hashref per row.
Only the columns you list in `columns` are shown, in that order.

**Vertical headers** (`header => 'vert'`) become left-hand cells with a
`rowspan` covering all rows that share the value — good for grouping. They sort
to the left and can nest to any depth. **Horizontal headers**
(`header => 'horiz'`) span the width and reappear whenever their value changes;
do not list horizontal-header columns in `columns` (defining them in
`column_defs` is enough). For headers to group correctly, your query must
`ORDER BY` those columns.

A cell can be a **widget** (making the table an editable form — name it inside
a `<form action="[process]">`) or a **link**, but not both. **Dynamic**
columns draw from internal counters rather than the query, `linecount` being
the common one for row numbers.

After running, the tag sets three scratch variables for the surrounding page:
`report_table_rowcount` (total rows emitted, including subheader and header
rows), `report_table_linecount` (data rows only — handy for a form's row
count), and `report_table_colspan` (columns used).

## Examples

A minimal report:

    <table>
    [report-table
        query="SELECT sku, description, price FROM products"
        columns="sku description price"
    ]
    </table>

Formatting and a link, via `column_defs`:

    <table>
    [report-table
        query="SELECT sku, description, price FROM products ORDER BY sku"
        columns="sku description price"
        column_defs="{
            price => { prefix => '$', filter => 'digits_dot', align => 'right' },
            sku   => { link => 'flypage', link_parm => 'code', link_key => 'sku' },
        }"
    ]
    </table>

An editable grid inside a form (the row count feeds `mv_nextpage` logic):

    <form action="[process]">
    <table>
    [report-table
        query="SELECT code, comment FROM userdb"
        columns="code comment"
        column_defs="{ comment => { widget => 'text', widget_cols => 30 } }"
    ]
    </table>
    <input type="hidden" name="rows" value="[scratch report_table_linecount]">
    <input type="submit" value="Save">
    </form>

## Notes

- The tag does not paginate. Add `LIMIT`/`OFFSET` to the query and build the
  paging controls yourself.
- The tag's own embedded documentation names the header-suppression option
  `display_colheaders`, but the code reads `colheaders` — use `colheaders`.
  Likewise the empty-cell substitute is `empty_cell`, not `empty`.
- Output is XHTML-style markup; the tag omits the outer `<table>` tags by
  design so you can add a form or extra rows around it.

## See also

- [query](query.md) — the general looping query tag
- [loop](loop.md) — iterate an arbitrary list
- [page](page.md) — the link mechanism used by `link`
- The [widgets reference](../widgets/) and [databases guide](../guides/databases.md)

## Source

Defined in `code/UserTag/report_table.tag` (inline `Routine`), registered as
`report-table`.
