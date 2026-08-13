# Database

Registers a database table for use with Interchange -- naming it, pointing
at its source file, and declaring its format -- and sets per-table
parameters. This is the directive you use to make any table
(`products`, `userdb`, a SQL table, a CSV file) available to ITL tags and
search.

**Scope:** both (`interchange.cfg` and `catalog.cfg`)

## Syntax

    Database  table  source_file  type
    Database  table  PARAMETER  value

Parsed by `parse_database`. The directive has two forms:

- **Definition** -- three tokens: the table name Interchange will use, the
  source data file, and the type. The type is one of `TAB`, `CSV`,
  `PIPE`, `LINE`, an `ic:` internal class, an `ldap:` spec, or a DBI/SQL
  data source name (`dbi:...`) for a SQL table.
- **Parameter** -- the table name followed by a `PARAMETER` keyword and a
  value, setting one attribute of an already-named table (for example
  `KEY`, `INDEX`, `COLUMN_DEF`, `USER`, `PASS`, `DSN`).

The first line naming a table defines it; later lines with the same table
name add parameters. Default: empty (no tables beyond those Interchange
sets up itself).

## Description

The table name is an arbitrary handle -- use word characters, and by
convention a single case. Interchange stores each definition as a hash of
attributes keyed by table name.

The value's third token selects the storage type. A numeric type or one
of the flat-file keywords (`TAB`, `CSV`, ...) builds a file-backed table
from the source file (relative to [ProductDir](ProductDir.md)); a
`dbi:`-prefixed type builds a SQL-backed table via DBI, storing the data
source name as the table's `DSN`. Parameter lines then refine the table:
`USER`/`PASS` for SQL credentials, `KEY` for the primary key column,
`COLUMN_DEF` for column types, `INDEX` for indexes, and many more.

### Catalog

This is the normal scope. Tables defined in `catalog.cfg` belong to that
catalog and are tied at catalog startup. Almost every real `Database`
line lives here.

### Global

`Database` is also a global directive. A definition in `interchange.cfg`
is stored in `$Global::Database`, and at table-tie time
`lib/Vend/Data.pm` copies every global definition into each catalog's own
`Database` set before tying:

```perl
if($Global::Database) {
    copyref($Global::Database, $Vend::Cfg->{Database});
}
```

So a globally defined table becomes available to all catalogs -- a way to
share one table definition across a multi-catalog server. A catalog's own
`Database` line for the same name overrides the global one. (Historic
documentation stated that global-level `Database` definitions "won't
work"; the current code copies them into every catalog, so they do.)

## Examples

The most basic table -- the tab-separated products file:

```
Database products products.txt TAB
```

A CSV-format table:

```
Database reviews reviews.txt CSV
```

A SQL table with credentials and key, built up over several lines:

```
Database  orders  orders.txt  dbi:mysql:mydb
Database  orders  USER   interch
Database  orders  PASS   secret
Database  orders  KEY    code
Database  orders  INDEX  status
```

Share a table across every catalog by defining it in `interchange.cfg`:

```
Database  country  country.txt  TAB
```

## Notes

Interchange uses "table" and "database" interchangeably; a `Database`
directive registers one table. Set [DatabaseDefault](DatabaseDefault.md)
parameters *before* the `Database` lines they should apply to, since
defaults are folded in when a table is first defined. To auto-register
every table in a live SQL database instead of naming each one, see
[DatabaseAuto](DatabaseAuto.md).

## See also

[DatabaseDefault](DatabaseDefault.md), [DatabaseAuto](DatabaseAuto.md),
[DatabaseAutoIgnore](DatabaseAutoIgnore.md), [Replace](Replace.md),
[ProductDir](ProductDir.md), [NoImport](NoImport.md), the
[databases](../guides/databases.md) guide.

## Source

Parsed by `parse_database` in `lib/Vend/Config.pm` (storing to
`$C->{Database}` for catalogs or `$Global::Database` globally); consumed
by `tie_database` in `lib/Vend/Data.pm`.
