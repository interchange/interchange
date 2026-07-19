# display

Render a single HTML form element for a database column, driven by the
column's metadata. It is part of the administrative UI toolset (loaded only
when the admin UI is enabled), not a storefront tag; it is the building
block the admin uses to lay out edit forms, but you can call it on any page
where the UI is loaded.

## Syntax

    [display table column key]
    [display column=... type=select options=... value=...]

Standalone tag. Its output is interpolated by default.

## Attributes

The tag accepts a large, open-ended attribute set (it takes all attributes
and merges them with any metadata record it finds). The most commonly used:

| Attribute | Default | Description |
|-----------|---------|-------------|
| `table`   |         | Table the column belongs to (used to look up metadata and, with `key`, a current value). |
| `column`  |         | Column name; also the default form-field `name`. |
| `key`     |         | Row key; when given with `table`/`column`, supplies the current value. |
| `name`    | `column`| The HTML form-field name. |
| `value`   |         | Current value; if omitted it is read from `table`/`column`/`key`. |
| `type`    |         | Widget type (`text`, `select`, `textarea`, `radio`, `checkbox`, `date`, a custom widget, ...). |
| `options` |         | Option list for choice widgets, or a keyword such as `tables`, `columns`, `keys`, `filters`. |
| `lookup`  |         | Column whose values populate a lookup-driven choice widget. |
| `field`   |         | Display column paired with `lookup` (value shown to the user). |
| `filter`  |         | Filter(s) applied to the current value before display. |
| `meta_table` | `mv_metadata` | Metadata table consulted for the column's widget definition. |
| `ui_no_meta_display` | | If true, skip the metadata lookup and use only the passed attributes. |

Positional order: `table`, `column`, `key` (the first three parameters).
Aliases: `base` for `table`; `database` for `db`; `col` for `column`;
`row` and `code` for `key`.

## Description

`display` is a thin, metadata-aware front end to Interchange's widget
system (the same system behind [widget](widget.md)). Given a `table` and
`column`, it looks up a metadata record — by default from the `mv_metadata`
table, overridable with `meta_table` or the `UI_META_TABLE` variable — that
describes how that column should be edited: its widget `type`, label,
option list, filters, and so on. Attributes you pass to the tag override the
metadata record field by field, so you can start from the stored definition
and adjust it per call.

If no current `value` is passed and a `table`, `column`, and `key` are all
available, the tag reads the current value from the database. Several
`options` keywords are expanded automatically: `tables` becomes the list of
databases, `columns` the columns of a table, `keys` the keys of a table,
and `filters` the available filters.

The tag returns the HTML for one form element (input, select, textarea,
etc.). It does not emit a `<form>` wrapper.

## Examples

A country drop-down populated from the `country` table, defaulting to the
current session value:

    [display name="country" table="country" lookup=code field=name
             type="select" value="[value country]"]

A billing-country drop-down with a leading "please select" option:

    [display name="b_country" table="country" lookup=code field=name
             type="select" value="[value b_country]"
             options="=-- [L]Please select[/L] --"]

Render the metadata-defined widget for the `description` column of the
`products` table for a specific SKU (uses the demo `products` table):

    [display table=products column=description key=os28004]

## Notes

- With no metadata record and no explicit `type`, the tag falls back to a
  default widget type; pass `type` to be sure of the element produced.
- The full behavior (views, extended metadata keys, custom widgets) lives in
  `Vend::Table::Editor`; only the widely used attributes are listed above.

## See also

- [widget](widget.md) — the underlying widget renderer
- [table_editor](table_editor.md) — full metadata-driven edit forms
- [Widgets reference](../widgets/) — available widget types
- The [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/display.coretag`. Implemented by the MapRoutine
`Vend::Table::Editor::display` (in `lib/Vend/Table/Editor.pm`).
