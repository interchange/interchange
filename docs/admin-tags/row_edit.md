# row_edit

Render the editable cells for one database row as a horizontal strip of table
cells, one form widget per column, for the admin UI's spreadsheet-style
multi-row editor. Reach for it inside a `<tr>` when you are building a grid where
each catalog row is edited in place. This tag is part of the admin UI toolset
(the tags in `code/UI_Tag/`, loaded when the admin UI feature is enabled), not a
storefront tag.

## Syntax

    [row_edit key=code table=products]
    [/row_edit]

    [row_edit key=code table=products size=20 columns="description price"]
    [/row_edit]

Container tag (declares an end tag; the body is unused by the routine).
`Interpolate` is on. The tag returns a run of `<td>` cells (no surrounding
`<table>` or `<tr>`); you place it inside a table row you build yourself.

## Attributes

| Attribute          | Default | Description |
|--------------------|---------|-------------|
| `key`              | none    | Primary key of the row to edit. Empty renders a header row of column names. |
| `table`            | `mv_data_table` (CGI) | Table to edit; returns `BLANK DB` if none resolves. |
| `size`             | metadata or `12` | HTML `size` of text inputs (and columns of textareas). |
| `columns`          | metadata or all | Whitespace/comma/null-separated column list; unknown columns are dropped, order is preserved. |
| `view`             | CGI `ui_meta_view` | Metadata view whose `spread_*` settings drive columns, widths, and widget choice. |
| `blank`            | off     | Render empty widgets (for a new/blank row) rather than the row's stored values. |
| `textarea`         | none    | Columns to render as `<textarea>` rather than a text input. |
| `height`           | `4`     | Rows for textarea widgets. |
| `pointer`          | none    | Numeric prefix (digits extracted) prepended to every field name. |
| `stacker`          | none    | Suffix appended to every field name as `__<stacker>`, for stacked multi-row submits. |
| `extra`            | none    | Extra HTML attributes for the `<td>`/input cells. |
| `meta_extra`       | none    | Extra attributes for metadata-driven cells. |
| `textarea_extra`   | none    | Extra attributes for textarea cells. |
| `ui_meta_specific` | off     | Passed through to the [display](display.md) widget lookup. |

Positional order: `key`, `table`, `size`, `columns`. Remaining named attributes
are collected as options (`addAttr`).

## Description

For each selected column the tag emits one `<td>` containing an input widget
whose `name` is the column (optionally wrapped by `pointer` prefix and `stacker`
suffix so many rows can post at once). The widget type is chosen per column:

- Columns listed in the view's `spread_meta` (and not suppressed by
  `ui_no_meta_display`) are rendered through the [display](display.md) tag, so
  they use whatever widget their `mv_metadata` record specifies.
- Columns named in `textarea` or in the view's `spread_textarea` become
  `<textarea>` boxes (`height` rows, `size` columns), HTML-escaped.
- All other columns become plain text inputs of width `size`.

The column set comes from `columns`, else the view's `spread_cols`/`attribute`,
else every column of the table; it is then filtered against the table's real
columns and against the user's table access-control list (ACL). If `key` names a
row that does not exist the cells show `DELETED` (or `ERROR`/`Not available`);
if there is no `key` and `blank` is off, the tag instead emits `<th>` heading
cells for the columns, which is how you render the grid's header line.

The metadata view is read with `Vend::Table::Editor::meta_record`; the metadata
table defaults to the `UI_META_TABLE` variable or `mv_metadata`.

## Examples

A header row followed by an editable row for one product, using the strap demo
`products` table:

    <table>
    <tr>[row_edit table=products columns="sku description price"][/row_edit]</tr>
    <tr>[row_edit key=os28004 table=products columns="sku description price"][/row_edit]</tr>
    </table>

An editable grid over search results, giving each row a distinct field
namespace with `stacker` so the whole page submits as a batch:

    [search-region ...]
    <table>
    [item-list]
    <tr>[row_edit key="[item-code]" table=products stacker="[item-code]"][/row_edit]</tr>
    [/item-list]
    </table>
    [/search-region]

## Notes

`row_edit` only produces the cells; supplying the enclosing `<form>`, `<table>`,
`<tr>` rows, and the submit handling is your responsibility. For a complete,
self-contained record editor use [table_editor](table_editor.md) instead.

## See also

- [table_editor](table_editor.md)
- [display](display.md)
- Concepts: [admin UI](../guides/admin-ui.md), [databases](../guides/databases.md)

## Source

Defined in `code/UI_Tag/row_edit.coretag` as an inline `UserTag` Routine
(registered `UserTag row-edit`; hyphen and underscore spellings are equivalent
when invoking the tag). Column widgets are rendered through
`Vend::Table::Editor::meta_record` and the [display](display.md) tag.
