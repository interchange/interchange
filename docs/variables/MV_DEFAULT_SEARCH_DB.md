# MV_DEFAULT_SEARCH_DB

Makes an unqualified search default to a database search instead of a text
(file) search. Reach for it so that plain search forms query your SQL/DBM
tables rather than scanning a flat file.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_DEFAULT_SEARCH_DB  1

A boolean flag. Default: off (text search unless the search specifies
otherwise).

## Description

When a search request does not explicitly choose a search type, Interchange
decides between a text search and a database search. With
`MV_DEFAULT_SEARCH_DB` set true, the default becomes a database search. The
standard demo catalogs set this to `1` in their variable data so that ordinary
searches hit the [MV_DEFAULT_SEARCH_TABLE](MV_DEFAULT_SEARCH_TABLE.md).

## Examples

Default searches to the database:

    Variable  MV_DEFAULT_SEARCH_DB  1

## See also

[MV_DEFAULT_SEARCH_TABLE](MV_DEFAULT_SEARCH_TABLE.md),
[MV_DEFAULT_SEARCH_FILE](MV_DEFAULT_SEARCH_FILE.md),
[MV_DEFAULT_MATCHLIMIT](MV_DEFAULT_MATCHLIMIT.md), the
[search](../guides/search.md) guide.

## Source

Consumed in `lib/Vend/Scan.pm` via `$::Variable->{MV_DEFAULT_SEARCH_DB}`.
