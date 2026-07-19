# db-date

Return the last-modified time of a database table's source text file,
formatted with POSIX `strftime`. Useful for showing a "catalog last updated"
date when your tables are built from flat files.

## Syntax

    [db-date]
    [db-date TABLE FORMAT]
    [db-date table=TABLE format=FORMAT]

Standalone tag. The returned string is not reparsed.

## Attributes

| Attribute | Default          | Description |
|-----------|------------------|-------------|
| `table`   | `products`       | Interchange database (table) name. |
| `format`  | `%A %d %b %Y`    | POSIX `strftime` format string. |

Positional order: `table`, `format`.

## Description

The tag stats the source text file of the named table -- built as
`ProductDir/` plus the table's configured `file` -- and returns its
modification time run through `strftime` with `format`. If the file cannot be
stat'd (for example it does not exist), the tag logs an error and returns
nothing.

## Examples

Show when the `products` table's source file was last written, using the
default format:

    [db-date]

produces something like:

    Tuesday 15 May 2001

Format the modification time of another table:

    [db-date table=inventory format="%Y-%m-%d %H:%M"]

## Notes

This tag reports the modification time of a table's *source text file*, so it
is only meaningful for file-based databases (the strap demo's `*DB` table
types). For SQL-backed tables the flat source file is generally not kept in
sync with the live data, so the time returned will not reflect real updates.

## See also

[convert-date](convert-date.md),
[data](data.md),
[../guides/databases.md](../guides/databases.md),
[ProductDir](../config/ProductDir.md)

## Source

Defined in `code/UserTag/db_date.tag` (registers the tag `db-date`).
Implemented by the inline Routine in that file.
