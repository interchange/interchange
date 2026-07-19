# export_database

Write a database table back out to its text source file, or add/remove a
column, from within a page. It is part of the administrative UI toolset
(loaded only when the admin UI is enabled), not a storefront tag; the admin
uses it on its "export table" screen to flush an edited table to disk.

## Syntax

    [export_database table]
    [export_database table=t file=f type=TAB sort=...]

Standalone tag. Interchange treats `-` and `_` as equivalent in tag names,
so the shipped admin writes it as `[export-database ...]`; that is the same
tag.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `table`   |         | The database table to export. |
| `file`    | table's configured source | Output file to write. |
| `type`    | table's configured type | Delimiter type (`TAB`, `PIPE`, `CSV`, ...); ignored if `file` is empty. |
| `sort`    |         | Sort specification for the exported rows. |
| `field`   |         | Add or remove this column (see below) instead of a plain export. |
| `delete`  |         | With `field`, remove that column (requires `verify`). |
| `verify`  |         | Required alongside `delete` as a safety confirmation. |

Positional order: `table`, `file`, `type` (the first three parameters).

## Description

The tag is a front end to `Vend::Data::export_database`. It marks the table
writable and writes its current contents to the text source file in the
configured (or requested) delimiter format. With `sort`, rows are ordered in
the output.

With `field`, the tag alters the table's structure instead:

- `field=NAME` adds a column.
- `field=NAME delete=1 verify=1` removes a column. `delete` without `verify`
  is refused and logged.

**Submission guard.** The routine first deletes `$Values->{ui_export_database}`
and returns nothing unless that value was set. In other words it only acts
when the form value `ui_export_database` is present, so a page can guard the
export behind a submit button and avoid exporting on every render.

## Examples

Export a table using values collected from an admin form, capturing the
result with [seti](../tags/seti.md):

    [seti result][export_database
        table="[value mv_data_table]"
        file="[value mv_data_file]"
        type="[value mv_data_export_type]"
        sort="[if value ui_sort_field][value ui_sort_field]:[value ui_sort_option][/if]"
    ][/seti]

Add a column to a table:

    [export_database table=products field=promo_flag]

## Notes

- Because of the `ui_export_database` guard, calling this tag in isolation on
  a page does nothing unless that form value is set first.
- Deleting a column is destructive; the `verify` requirement is the only
  built-in safeguard.

## See also

- [import_fields](import_fields.md) — load a table from a text file
- The [databases guide](../guides/databases.md)
- The [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/export_database.coretag`. Implemented by the inline
Routine, which calls `Vend::Data::export_database`.
