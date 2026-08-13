# widget_meta

Return the meta record (the default option hash) associated with a form-widget
type. Reach for it when an admin page or the table editor needs the stored
metadata that configures how a widget of a given type is presented.

This tag is part of the administrative UI toolset: it is loaded from
`code/UI_Tag/` when the back-office UI is enabled, and is not a storefront
tag.

## Syntax

    [widget_meta type=WIDGETTYPE]
    [widget_meta WIDGETTYPE]

Standalone tag (no end tag). It returns a hash reference (see Notes); any
scalar output is reparsed as Interchange Tag Language (ITL) by default.

The tag name is registered as `widget-meta`; Interchange treats hyphens and
underscores in tag names interchangeably, so `[widget_meta]` and
`[widget-meta]` are the same tag.

## Attributes

| Attribute    | Default        | Description |
|--------------|----------------|-------------|
| `type`       | none           | Widget type whose meta record to return (for example `select`, `date`). Positional parameter 1. |
| `view`       | none           | Meta view to select, passed through to the meta lookup. |
| `meta_table` | `mv_metadata`  | Metadata table to consult (defaults to the catalog's `UI_META_TABLE`, normally `mv_metadata`). |

Positional order: `type`.

The tag declares `addAttr`, so additional attributes are accepted and passed
through in the options hash.

## Description

`[widget_meta]` is a MapRoutine tag implemented by
`Vend::Table::Editor::widget_meta`. It resolves the metadata for a widget type
in this order:

1. A record for `_widget::TYPE` in the metadata table (via `meta_record`,
   honoring `view` and `meta_table`). If found, it is returned.
2. Otherwise, the `ExtraMeta` string attached to the widget's catalog-level
   code definition (`$Vend::Cfg->{CodeDef}{Widget}`), parsed into an option
   hash.
3. Otherwise, the `ExtraMeta` string on the global widget code definition
   (`$Global::CodeDef->{Widget}`).
4. Otherwise, the built-in `$Vend::Form::ExtraMeta{TYPE}`.

The result is a hash reference of the widget's default meta settings. This
feeds the table editor and metadata forms, which read those defaults when
building an editing control for a column that uses the widget.

## Examples

Fetch the meta record for the `date` widget (used programmatically):

    [widget_meta type=date]

Within embedded Perl, where the returned hash reference is directly usable:

    [perl]
        my $meta = $Tag->widget_meta('yesno');
        return $meta->{label} || '';
    [/perl]

## Notes

- The tag returns a hash reference, not printable text. On a page it renders as
  its Perl stringification (for example `HASH(0x55...)`); use it from embedded
  Perl, or pass the result to a tag that consumes a hash reference. This
  matches how the table editor uses it internally.
- When no metadata, code-definition `ExtraMeta`, or built-in `ExtraMeta`
  exists for the type, the tag returns undef.

## See also

- [widget](widget.md) — render a form widget
- [widget_info](widget_info.md) — query a widget definition's attributes
- [meta_record](meta_record.md) — the underlying metadata lookup
- [table_editor](table_editor.md) — the main consumer of widget metadata

## Source

Defined in `code/UI_Tag/widget_meta.coretag`. Implemented by
`Vend::Table::Editor::widget_meta` in `lib/Vend/Table/Editor.pm`, which calls
`meta_record` and reads widget `ExtraMeta` definitions.
