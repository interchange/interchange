# meta_record

Return the complete metadata record for a meta item as a hash reference,
merging the meta table row with its serialized `extended` settings. Reach for
it from Perl in the admin UI when you need the full set of a field's or table's
meta options at once, rather than one key as with [meta_info](meta_info.md).

`[meta_record]` is part of the admin UI tag set in `code/UI_Tag/`, loaded when
the administrative interface is enabled; it is not a storefront tag.

## Syntax

    [meta_record item view source]
    [meta_record item=products::description view=viewname]

Standalone tag (no end tag). It returns a hash reference, so it is meant to be
used from a `[perl]`/`[calc]` block (`$Tag->meta_record(...)`); interpolated
directly into a page it stringifies to a `HASH(0x...)` reference.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `item` | none (required) | The meta item to read, for example a table name or `table::column`. Alias: `table`. |
| `view` | none | Meta view; the lookup tries `view::item` first, then falls back to the plain item. |
| `source` | `mv_metadata` (or `UI_META_TABLE`) | The metadata table name, or a hash reference used directly as the record. |

Positional order: `item`, `view`, `source`.

## Description

`[meta_record]` is a `MapRoutine` tag: it maps directly to
`Vend::Table::Editor::meta_record`. That routine reads the row keyed by the
item (or `view::item`) from the meta table, then unpacks the row's serialized
`extended` field — a stored option hash — and merges those keys into the
record. When a `view` is active and the extended data carries per-view
settings, the view's overrides are merged on top.

The result is a single hash reference holding every configured setting for the
item (`label`, `type`, `width`, `filter`, `help`, and any custom keys). It
returns undefined when no matching meta record exists.

## Examples

Fetch the whole meta record for a products column and read two settings from
it in Perl:

    [calc]
        my $rec = $Tag->meta_record('products::description');
        return '' unless $rec;
        return "$rec->{label} ($rec->{type})";
    [/calc]

might return:

    Description (textarea)

Fetch a record under a named view:

    [calc]
        my $rec = $Tag->meta_record('transactions::status', 'expand');
        return $rec->{type};
    [/calc]

## Notes

For a single setting, [meta_info](meta_info.md) is simpler; it wraps the same
`meta_record` routine and returns one key as a plain string. Use
`[meta_record]` when you need several settings from the same record without
repeating the lookup.

The `extended_only` and `overlay` parameters that
`Vend::Table::Editor::meta_record` accepts are not exposed through this tag's
positional interface.

## See also

- [meta_info](meta_info.md) — a single setting from the record
- [table_editor](table_editor.md)
- Concepts: [databases](../guides/databases.md),
  [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/meta_record.coretag` (registered `UserTag meta-record`,
`attrAlias table item`). Implemented by `Vend::Table::Editor::meta_record` in
`lib/Vend/Table/Editor.pm` (MapRoutine).
