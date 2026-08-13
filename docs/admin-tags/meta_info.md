# meta_info

Return a single named setting from a metadata (`mv_metadata`) record. Reach for
it to pull one attribute — a field's display label, widget type, help text, and
so on — for a table, column, or arbitrary meta item in the admin UI.

`[meta_info]` is part of the admin UI tag set in `code/UI_Tag/`, loaded when
the administrative interface is enabled; it is not a storefront tag.

## Syntax

    [meta_info table column key]
    [meta_info table=transactions col=company key=label localize=1]

Standalone tag (no end tag). Returns the requested setting as a string, or
empty when no matching meta record or key exists.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `table` | none | Table name; combined with `column` to form the meta item `table::column`. |
| `column` | none | Column name. Alias: `col`. |
| `key` | none | The name of the setting to return from the meta record (for example `label`, `type`, `width`, `help`). |
| `item` | derived from `table`/`column` | Explicit meta item name, used when you do not build it from `table`/`column`. |
| `meta_table` | `mv_metadata` (via `meta_record`) | Metadata table to read from. |
| `view` | none | Meta view; looks up `view::item` first. |
| `specific` | none | An extra qualifier tried first as `item::specific` before the plain item. |
| `extended_only` | off | Only return settings stored in the record's serialized `extended` field. |
| `localize` | off | Pass the returned value through `[msg]`/`errmsg` for locale translation. |

Positional order: `table`, `column`, `key`. Because the tag declares
`addAttr`, the remaining options are read from the option hash.

## Description

`[meta_info]` builds a meta item name and looks up its record through
`Vend::Table::Editor::meta_record` (the same routine behind
[meta_record](meta_record.md)), then returns the single setting named by `key`.

The item is `table::column` when both are given, `table` alone when only it is
given, or the explicit `item`. When `specific` is set, `item::specific` is
tried first, falling back to the plain item. The record combines the columns of
the meta table row with any keys unpacked from its serialized `extended` field.

If no meta record is found, or the record lacks `key`, the tag returns
undefined (empty). With `localize` set, the returned value is run through the
catalog's message translation before being returned.

## Examples

Get the display label configured for the `company` column of the
`transactions` table (as the admin customer page does):

    [meta_info table=transactions col=company key=label localize=1]

might return:

    Company

Get the widget type configured for a products column:

    [meta_info table=products col=description key=type]

## Notes

`[meta_info]` returns one setting; to retrieve the whole meta record as an
option hash for a table editor, use [meta_record](meta_record.md).

The set of recognized meta keys (`label`, `type`, `width`, `height`, `help`,
`filter`, and so on) is defined by the table-editor and form-widget machinery,
not by this tag.

## See also

- [meta_record](meta_record.md) — the full meta record
- [table_editor](table_editor.md), [display](display.md)
- Concepts: [databases](../guides/databases.md),
  [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/meta_info.coretag` as an inline `UserTag` Routine
(registered `UserTag meta-info`, `attrAlias col column`, `addAttr`). The
lookup is `Vend::Table::Editor::meta_record` in `lib/Vend/Table/Editor.pm`.
