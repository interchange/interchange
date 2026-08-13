# DatabaseAuto

Discovers the tables in a live SQL database and registers every one of
them with Interchange automatically, saving you from writing a
[Database](Database.md) line per table. Reach for it when you point
Interchange at an existing SQL schema and want all its tables available
without enumerating them.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    DatabaseAuto  DSN [username [password [catalog [schema [name [type]]]]]]

Parsed by `parse_dbauto`. The first three tokens are the DBI data source
name and the connection username and password. Any further tokens are
passed straight to DBI's `table_info` method as its `catalog`, `schema`,
`name`, and `type` arguments (shell-quoted; use `''` to skip a positional
slot). Default: empty (no auto-configuration).

## Description

Interchange connects to the named SQL database, asks DBI for its list of
tables, and for each table performs the equivalent of:

```
NoImport   TABLE
Database   TABLE  TABLE.txt  dbi:...
Database   TABLE  USER  username
Database   TABLE  PASS  password
```

so the table is registered and marked not to be imported from a text
file. Only real tables are picked up by default, not views; pass the DBI
`type` argument (for example `VIEW`) to change that. If the Perl module
`DBIx::DBSchema` is installed, Interchange also records each table's
`CREATE_SQL`, the DDL needed to recreate it.

Because DBI's `table_info` arguments are positional, the trailing tokens
let you restrict discovery -- most usefully the `schema`, to confine
auto-configuration to one schema (for example PostgreSQL's `public`).
This only works for SQL databases.

## Examples

Register every table in a MySQL database:

```
DatabaseAuto dbi:mysql:interchange interchange pass
```

Restrict discovery to PostgreSQL's `public` schema (skip the unused
`catalog` slot with `''`):

```
DatabaseAuto dbi:Pg:dbname=mydb myuser mypass '' public
```

Also pick up views, passing `VIEW` as the DBI `type`:

```
DatabaseAuto dbi:Pg:dbname=mydb myuser mypass '' public '' VIEW
```

Combine with an ignore pattern so system tables are skipped:

```
Variable SQLDSN  dbi:Pg:dbname=mydb
DatabaseAutoIgnore ^sql_
DatabaseAuto __SQLDSN__
NoImportExternal Yes
```

## Notes

To exclude tables by name (for instance those in other schemas), set
[DatabaseAutoIgnore](DatabaseAutoIgnore.md) *before* this directive, or
narrow the `schema` argument. A loose ignore pattern can drop more tables
than intended, so specifying the schema is often cleaner. Watch for
confusing results when the database user's `search_path` covers multiple
schemas holding same-named tables.

## See also

[DatabaseAutoIgnore](DatabaseAutoIgnore.md), [Database](Database.md),
[DatabaseDefault](DatabaseDefault.md), [NoImportExternal](NoImportExternal.md),
the [databases](../guides/databases.md) guide.

## Source

Parsed by `parse_dbauto` in `lib/Vend/Config.pm`, which calls
`Vend::Table::DBI::auto_config` and feeds each discovered table back
through `parse_database`.
