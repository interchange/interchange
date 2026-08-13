# MV_DEFAULT_SEARCH_FILE

Names the file a text search scans when the search request does not name one.
Reach for it to point default text searches at a specific data file.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_DEFAULT_SEARCH_FILE  filename

`filename` is the file (relative to the catalog) used for text searches.
Default: none set by the server; the demo catalogs set it to `products`.

## Description

For a text (file) search that does not specify `mv_search_file`, Interchange
uses `MV_DEFAULT_SEARCH_FILE` as the file to scan. It is read when the catalog
configuration is parsed and by the text-search back ends. The demo catalogs set
it in `catalog_before.cfg`/`catalog.cfg` to `products`.

For database searches, the analogous setting is
[MV_DEFAULT_SEARCH_TABLE](MV_DEFAULT_SEARCH_TABLE.md).

## Examples

Point default text searches at the products file:

    Variable  MV_DEFAULT_SEARCH_FILE  products

## See also

[MV_DEFAULT_SEARCH_TABLE](MV_DEFAULT_SEARCH_TABLE.md),
[MV_DEFAULT_SEARCH_DB](MV_DEFAULT_SEARCH_DB.md), the
[search](../guides/search.md) guide.

## Source

Consumed in `lib/Vend/Config.pm`, `lib/Vend/Glimpse.pm`, and
`lib/Vend/TextSearch.pm` via `$::Variable->{MV_DEFAULT_SEARCH_FILE}`.
