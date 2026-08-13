# table_editor

Generate a complete HTML form for editing or creating one row of a database
table, choosing a widget per column from the table's metadata. It is the
workhorse behind nearly every edit screen in the administrative interface. This
tag is part of the admin UI toolset (the tags in `code/UI_Tag/`, loaded when the
admin UI feature is enabled), not a storefront tag.

## Syntax

    [table_editor table=products key=os28004]

    [table_editor table=products key=os28004 fields="description price"]

    [table_editor table=products key=os28004]
    optional layout template
    [/table_editor]

Container tag. The body, when present, is an overall layout template for the
generated form; most callers omit it and let the tag build the standard layout.
Returns the form HTML.

## Attributes

The tag accepts a very large option set (widget overrides, labels, wizard and
tab controls, button text, success/fail pages, and more). The most commonly used
attributes and their aliases:

| Attribute       | Alias(es)                       | Default    | Description |
|-----------------|---------------------------------|------------|-------------|
| `mv_data_table` | `table`                         | none (req) | Table to edit. |
| `item_id`       | `key`                           | none (req) | Primary key of the row; blank/new creates a record. |
| `ui_data_fields`| `fields`, `mv_data_fields`      | all fields | Fields to edit, in order. |
| `ui_meta_view`  | `view`                          | none       | Metadata view selecting widgets, labels, and layout. |
| `ui_clone_id`   | `clone`                         | none       | Existing key to clone into the new record. |
| `ui_profile`    | `profile`                       | none       | Form profile to validate the submission against. |
| `ui_display_only` | `email_fields`                | none       | Fields shown read-only rather than as editable widgets. |
| `cgi`           |                                 | off        | Pull `key`, `view`, and related values from the request. |
| `hidden`        |                                 | none       | Hash of extra hidden form fields. |
| `default`       |                                 | none       | Hash of default values for a new record. |
| `wizard`        |                                 | off        | Render as a wizard step (Next/Back navigation). |
| `tabbed`        |                                 | off        | Lay the form out with [tabbed_display](tabbed_display.md). |
| `next_text`     |                                 | `OK`       | Label of the submit button. |
| `cancel_text`   |                                 | `Cancel`   | Label of the cancel button. |
| `mv_nextpage`   |                                 | current    | Page to go to after a successful save. |
| `mv_failpage`   |                                 | current    | Page to go to when validation fails. |

Positional order: `mv_data_table`, `item_id`. Remaining named attributes are
collected as options (`addAttr`). The full attribute list is extensive; see the
Source section for the authoritative enumeration.

## Description

Given a table and a key, the tag reads the row (or prepares a blank/cloned one),
determines the field list from `ui_data_fields` or the table's columns, and for
each field renders the widget its `mv_metadata` record specifies — text input,
select, date, textarea, and so on — with the field's label and inline help. It
wraps the widgets in a form that posts back to Interchange's data-update
machinery, adds OK/Cancel (and, in wizard mode, Back/Next) buttons, and can
validate the submission against a form profile named by `ui_profile`, sending
the user to `mv_nextpage` on success or `mv_failpage` on failure.

The layout can be a flat table, a multi-tab display (`tabbed`), or a wizard
sequence (`wizard`). Access-control lists restrict which fields and keys a given
admin user may see or change. Because the widget choice, labels, help text, and
grouping all come from the metadata table, most customization is done by editing
`mv_metadata` rather than by passing attributes here.

## Examples

Edit an existing product from the strap demo `products` table:

    [table_editor table=products key=os28004]

Edit only two fields, taking the key from the request:

    [table_editor table=products cgi=1 fields="description price"]

Create a new product record with some defaults filled in:

    [table_editor table=products key="" default.category="Hand Tools"]

Use a metadata view and tabbed layout:

    [table_editor table=products key=os28004 view=expanded tabbed=1]

## Notes

`table_editor` may not work for a table whose primary key column is literally
named `id`, because `id` is mapped to the session id in `etc/varnames`; remove
the `mv_session_id id` line there if you must edit such a table.

Given the size of the option set, treat the metadata table and the source as the
reference for advanced behavior; the attribute table above covers the common
cases only.

## See also

- [row_edit](row_edit.md) — editable cells for one row inside a larger grid
- [tabbed_display](tabbed_display.md)
- [display](display.md)
- Concepts: [admin UI](../guides/admin-ui.md), [databases](../guides/databases.md),
  [forms](../guides/forms.md)

## Source

Defined in `code/UI_Tag/table_editor.coretag` (registered `UserTag
table-editor`; hyphen and underscore spellings are equivalent when invoking the
tag). Implemented by `Vend::Table::Editor::editor` (MapRoutine).
