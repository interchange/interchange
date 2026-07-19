# backup_database

Export one or more database tables to flat files in a backup directory, with
optional gzip compression, an aggregate download file, and Excel (`.xls`)
output. This is what the admin UI "database download / backup" screen calls.
This tag is part of the Interchange admin UI toolset (the tags in
`code/UI_Tag/`, loaded when the admin UI feature is enabled), not a storefront
tag.

## Syntax

    [backup_database tables]
    [backup_database tables="products inventory" compress=1 xls=1]

Standalone tag (no end tag). The return value is a count (or empty when
`hide` is set); it is not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute        | Default | Description |
|------------------|---------|-------------|
| `tables`         | none    | Whitespace- or comma-separated list of table names to export. |
| `dir`            | see below | Backup directory. Defaults to the `BACKUP_DIRECTORY` variable, or `VendRoot/backup`. |
| `compress`       | not set | Also write a gzip (`.gz`) copy of each exported file (removing the plain file). Requires `Compress::Zlib`. |
| `xls`            | not set | Also write all tables into a single `DBDOWNLOAD.xls` workbook. Requires `Spreadsheet::WriteExcel`. |
| `max_xls_string` | `255`   | Maximum cell string length before values are split across rows in the `.xls` output. |
| `gnumeric`       | not set | Also build an aggregate `DBDOWNLOAD.all` file with all tables, quoting numeric-looking fields for spreadsheet import. |
| `where`          | none    | SQL `WHERE` clause passed to the export, to back up a subset of rows. |
| `force`          | not set | Export even tables marked `NoExportExternal`. |
| `hide`           | not set | Return an empty string instead of the table count. |

Positional order: `tables`.

The tag declares `AddAttr`, so all options above are read from the options
hash.

## Description

For each named table, `[backup_database]` calls Interchange's `export` routine
to write a `TAB`-delimited file into the backup directory, named after the
table's source file. It counts the tables successfully written and returns that
count (unless `hide` is set).

Optional outputs layer on top of the per-table files:

- `compress` gzips each file to `FILE.gz` and removes the plain copy.
- `gnumeric` concatenates the tables into `DBDOWNLOAD.all`, separated by form
  feeds and with numeric-looking cells prefixed with a quote so a spreadsheet
  imports them as text.
- `xls` builds a single `DBDOWNLOAD.xls` workbook with one worksheet per table,
  splitting overly long strings across rows at `max_xls_string`.

Any per-table errors are collected and stored as an HTML list in the scratch
variable `ui_error`; they do not abort the remaining tables.

## Examples

Back up two tables to the default backup directory:

    [backup_database tables="products inventory"]

Back up all product tables as a compressed set plus an Excel workbook, without
printing the count:

    [backup_database
        tables="products variants inventory"
        compress=1
        xls=1
        hide=1
    ]

## Notes

The `compress`, `xls`, and `gnumeric` outputs each depend on an optional CPAN
module (`Compress::Zlib`, `Spreadsheet::WriteExcel`). If a module is missing,
that output is silently skipped: `xls` is turned off, and compression eval
errors are recorded in `ui_error`.

The backup directory must exist and be writable by the server; the tag does not
create it.

## See also

- [backup_file](backup_file.md)
- [export_database](export_database.md)
- [import_fields](import_fields.md)
- Concepts: [databases](../guides/databases.md), [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/backup_database.coretag` (registered as the tag
`backup-database`; ITL treats hyphen and underscore in tag names as
equivalent). Implemented by the inline Routine, which calls Interchange's
`export` function.
