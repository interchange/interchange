# dbi_quote

Quotes a value for safe inclusion in an SQL statement, using the DBI/DBD
`quote` method of a specific database.

## Syntax

    [filter dbi_quote]TEXT[/filter]
    [filter dbi_quote.TABLE]TEXT[/filter]
    [value name=field filter="dbi_quote"]

The optional dotted argument `TABLE` names the table whose database handle
is used for quoting. When omitted, the handle of the catalog's first
[ProductFiles](../config/ProductFiles.md) database is used.

## Description

The filter looks up the database handle for `TABLE` (or the first
`ProductFiles` database by default) and returns `$db->quote($value)`. This
delegates to the DBI driver (DBD) for that database, so the result honors
every quoting rule of the specific backend: surrounding quotes, doubled or
backslash-escaped quote characters, truncation at the first ASCII NUL for
PostgreSQL, newline handling for MySQL, and so on.

The result therefore *includes* the surrounding quote characters and is
meant to be dropped straight into an SQL statement. This differs from the
generic [sql](sql.md) filter, which applies Interchange's own quoting
rather than the driver's.

If no database handle can be found for the named table, the filter logs an
error and returns undefined.

Because the filter obtains a live database handle, [Safe](../glossary.md)
restrictions apply when it is used through the `$Tag` object inside an
embedded Perl block.

## Examples

Assuming the default database is a typical SQL backend:

    [cgi name=code set="That's all" hide=1]
    [value name=code filter="dbi_quote"]

produces (including all quotes):

    'That''s all'

Quoting a literal string with an explicitly named database:

    [filter dbi_quote.sets]some string \ or other[/filter]

For MySQL or PostgreSQL this yields `'some string \\ or other'`; for
Oracle, `'some string \ or other'` — the exact escaping is the driver's.

## See also

- [sql](sql.md)
- [backslash](backslash.md)
- [databases guide](../guides/databases.md)

## Source

Defined in `code/Filter/dbi_quote.filter`.
