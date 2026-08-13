# export

Write a database table back out to its text (ASCII) source file. Reach for
it after code has updated rows in memory or on disk and you want the flat
source file that seeds the table refreshed to match, or when you need to
add or remove a column.

## Syntax

    [export TABLE]
    [export table=TABLE file=FILE type=TAB]
    [export table=TABLE field=COLUMN]
    [export table=TABLE field=COLUMN delete=1 verify=1]

Standalone tag. Returns the export status unless `hide` is set. This is an
administrative operation, normally used from trusted admin pages or jobs.

## Attributes

| Attribute | Default            | Description |
|-----------|--------------------|-------------|
| `table`   | (required)         | Name of the table to export; positional parameter 1. |
| `file`    | table's source     | Output file; defaults to the table's configured source file, relative to the catalog unless absolute. |
| `type`    | table's format     | Output format/delimiter (for example `TAB`, `CSV`, `PIPE`, `%%`); defaults to the table's configured type. |
| `field`   | (none)             | Column to add (or, with `delete`, remove) during export. |
| `delete`  | (off)              | Delete the column named by `field`; only takes effect when `verify` is also set. |
| `verify`  | (off)              | Confirm a `delete` (guards against accidental column removal). |
| `sort`    | (none)             | Sort specification, in `field:option` form, applied to the exported rows. |
| `where`   | (none)             | SQL `WHERE` clause (string or hash) restricting which rows are exported. |
| `force`   | (off)              | Export even when `NoExport` or `NoExportExternal` would otherwise skip this table. |
| `hide`    | (off)              | Suppress the status return value, emitting nothing. |

Positional order: `table`.

Aliases: `base` for `table`, `database` for `table`.

## Description

`[export]` calls `Vend::Data::export_database`, which walks the table and
rewrites its source file using the appropriate delimiter. When you omit
`file` and `type`, the values configured for that table are used, so a bare
`[export products]` round-trips the products table to its own source file
in its own format.

The `field` option restructures the table: with `field=COLUMN` it appends a
new column, and with `field=COLUMN delete=1 verify=1` it removes an
existing one. The `verify` requirement means a stray `delete` without it is
ignored rather than destroying data.

Two directives can block an export: `NoExport` (per table) and
`NoExportExternal` (SQL/LDAP tables). Pass `force=1` to override them when
you deliberately need the flat file written anyway. External (SQL) tables
without `force` are silently skipped, since their authoritative data lives
in the database, not the source file.

## Examples

Export the products table to its own source file in its own format:

    [export products]

Export to a specific tab-delimited file:

    [export table=products file=products.txt type=TAB]

Add a `promo` column to the pricing table:

    [export table=pricing field=promo]

Export only the rows matching a condition:

    [export table=userdb where="acl = 'wholesale'"]

## Notes

This writes files on the server and can rewrite an entire table source, so
restrict it to admin pages or scheduled [jobs](../guides/jobs.md). The
`file` location is still subject to `NoAbsolute` and related path
restrictions.

## See also

[import](import.md), [data](data.md), the
[databases](../guides/databases.md) guide.

## Source

Defined in `code/SystemTag/export.coretag`, mapped to
`Vend::Interpolate::export` in `lib/Vend/Interpolate.pm`, which delegates to
`Vend::Data::export_database` in `lib/Vend/Data.pm`.
