# FileDatabase

Lets Interchange fall back to a database table for file contents when a file is
not found on disk. Reach for it to store page or component text in a table --
for example to serve per-language versions of a file from one keyed row.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    FileDatabase  table[:column]

The value is a table name, optionally followed by a colon and a column name.
The raw string is stored unparsed. Default: empty (feature off).

## Description

When Interchange reads a file through its file layer and the file does not
exist on disk, it consults `FileDatabase`. The value is split on colons into a
table and an optional column: Interchange looks up the requested file name as a
key in that table and returns the named column's contents as the file body.

If no column is given, the column defaults to the current value of the global
`LANG` variable; if a column named after `LANG` does not exist, Interchange
falls back to a column literally named `default`. This is what makes the table
form useful for internationalized content: one row per file, one column per
language, plus a `default` column.

Files on disk always win: the database is consulted only when the real file is
absent. The table itself must be registered first with a
[Database](Database.md) directive.

## Examples

Serve missing files from the `default` column (or the `LANG` column, when it
exists) of the `files` table:

```
Database     files files.txt TAB
FileDatabase files
```

Pin the lookup to a specific column:

```
FileDatabase files:data
```

## Notes

`FileDatabase` retrieves file *contents*, not directory listings; only names
that resolve to a key in the table are served this way. The column-selection
rule (`LANG`, then `default`) makes it a lightweight mechanism for
language-specific page bodies.

## See also

[Database](Database.md), [DirectiveDatabase](DirectiveDatabase.md),
[VariableDatabase](VariableDatabase.md), the [databases](../guides/databases.md)
and [internationalization](../guides/internationalization.md) guides.

## Source

Stored unparsed (`undef` parser) in `lib/Vend/Config.pm`; consumed by
`readfile_db` in `lib/Vend/File.pm`, which splits the value into table and
column and reads the file body from the table.
