# MV_DEFAULT_SEARCH_TABLE

Names the table a database search queries when the search request does not name
one. Reach for it to point default database searches at a specific table.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_DEFAULT_SEARCH_TABLE  table

`table` is a table name. A space- or comma-separated list of tables is also
accepted. Default: none set by the server; the demo catalogs set it to
`products`.

## Description

For a database search that does not name a table, Interchange uses
`MV_DEFAULT_SEARCH_TABLE`. It is read when the catalog configuration is parsed
and by the database-search back ends (`lib/Vend/DbSearch.pm`,
`lib/Vend/RefSearch.pm`). The demo catalogs set it to `products`. Pair it with
[MV_DEFAULT_SEARCH_DB](MV_DEFAULT_SEARCH_DB.md) so unqualified searches default
to the database.

## Examples

Default database searches to the products table:

    Variable  MV_DEFAULT_SEARCH_TABLE  products

## See also

[MV_DEFAULT_SEARCH_DB](MV_DEFAULT_SEARCH_DB.md),
[MV_DEFAULT_SEARCH_FILE](MV_DEFAULT_SEARCH_FILE.md),
[MV_DEFAULT_MATCHLIMIT](MV_DEFAULT_MATCHLIMIT.md), the
[search](../guides/search.md) guide.

## Source

Consumed in `lib/Vend/Config.pm`, `lib/Vend/DbSearch.pm`, and
`lib/Vend/RefSearch.pm` via `$::Variable->{MV_DEFAULT_SEARCH_TABLE}`.
