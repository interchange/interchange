# DatabaseAutoIgnore

Sets a regular expression that excludes matching table names from
[DatabaseAuto](DatabaseAuto.md) discovery. Reach for it when auto-config
would otherwise pull in system or unwanted tables from a SQL database.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    DatabaseAutoIgnore  REGEX

A regular-expression string (`parse_regex`), validated for syntax at
configuration time. A table whose name matches is skipped by
[DatabaseAuto](DatabaseAuto.md). Default: empty (ignore nothing).

## Description

[DatabaseAuto](DatabaseAuto.md) registers *every* table it finds in a SQL
database. `DatabaseAutoIgnore` gives you an exclusion filter: any
discovered table name matching this pattern is left unregistered. This is
the usual way to keep an auto-configured catalog from importing system
tables or tables in schemas you do not want.

Because the pattern is matched against each discovered name, a broad
expression can silently drop more tables than you intend. When your real
goal is "use only the public schema," passing the `schema` argument to
[DatabaseAuto](DatabaseAuto.md) directly is often more precise.

## Examples

Skip PostgreSQL's `sql_`-prefixed information-schema tables, then
auto-configure the rest:

```
DatabaseAutoIgnore  ^sql_
DatabaseAuto   dbi:Pg:dbname=mydb;host=dbhost  myuser  mypass
```

## Notes

This directive must be set **before** [DatabaseAuto](DatabaseAuto.md) to
have any effect, since it is consulted while `DatabaseAuto` walks the
table list.

## See also

[DatabaseAuto](DatabaseAuto.md), [Database](Database.md), the
[databases](../guides/databases.md) guide.

## Source

Parsed by `parse_regex` in `lib/Vend/Config.pm`; consumed by
`Vend::Table::DBI::auto_config` (invoked from `parse_dbauto`) when
filtering discovered tables.
