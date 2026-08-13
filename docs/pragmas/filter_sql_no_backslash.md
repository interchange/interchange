# filter_sql_no_backslash

Disables the backslash escaping normally performed by the
[sql](../filters/sql.md) filter. Set it for SQL-standard databases (such as
Oracle) that do not treat `\` specially, so the filter does not double your
backslashes.

**Default:** off — the `sql` filter escapes `\` to `\\`.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma filter_sql_no_backslash

Page-wide, anywhere in an Interchange page:

    [pragma filter_sql_no_backslash]
    [pragma filter_sql_no_backslash 0]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma filter_sql_no_backslash]1[/tag]

This is a boolean pragma.

## Description

The [sql](../filters/sql.md) filter escapes single quotes (`'` to `''`) and, by
default, backslashes (`\` to `\\`), so a value can be embedded safely in a
single-quoted SQL literal. Databases such as MySQL and PostgreSQL (in its
historical default mode) treat `\` as an escape character, so doubling
backslashes is correct there.

The SQL standard does not give `\` any special meaning. For standard-conforming
databases such as Oracle, doubling backslashes corrupts the data. When
`filter_sql_no_backslash` is set, the `sql` filter skips the backslash step and
escapes only single quotes.

## Examples

Enable it catalog-wide for an Oracle-backed catalog. In `catalog.cfg`:

    Pragma filter_sql_no_backslash

The `sql` filter then leaves backslashes intact:

    [filter sql]C:\path\to\file[/filter]

produces `C:\path\to\file` rather than `C:\\path\\to\\file`.

## Notes

This changes only the [sql](../filters/sql.md) filter's escaping. It does not
affect quoting done by DBI placeholders or by database drivers directly.

## See also

- [sql](../filters/sql.md) filter
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed by the `sql` filter in
`code/Filter/sql.filter`.
