# sql

Escapes a string for inclusion in an SQL statement, without reference to a
particular database driver.

## Syntax

    [filter sql]TEXT[/filter]
    [value name=field filter="sql"]

## Description

The filter doubles every single quote (`'` becomes `''`) so the value can be
placed inside a single-quoted SQL string literal. It also doubles every
backslash (`\` becomes `\\`) unless the
[filter_sql_no_backslash](../pragmas/filter_sql_no_backslash.md) pragma is
set, which is appropriate for databases (such as PostgreSQL with standard
strings) that do not treat backslash as an escape character.

This is a generic, driver-independent quoting helper. When you have a live
database handle, [dbi_quote](dbi_quote.md) performs quoting through DBI and
is preferred; `sql` is useful when building query text where no handle is
readily available.

## Examples

    [filter sql]O'Brien[/filter]

produces:

    O''Brien

A backslash is doubled by default:

    [filter sql]back\slash[/filter]

produces:

    back\\slash

With the `filter_sql_no_backslash` pragma set, the same input returns
`back\slash` unchanged apart from any quotes.

## See also

[dbi_quote](dbi_quote.md), [qb_safe](qb_safe.md),
[filter_sql_no_backslash](../pragmas/filter_sql_no_backslash.md)

## Source

Defined in `code/Filter/sql.filter`.
