# MV_DEFAULT_MATCHLIMIT

Sets the default number of results a search returns per page when the search
does not specify `mv_matchlimit`. Reach for it to change the catalog-wide
paging size of search results.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_DEFAULT_MATCHLIMIT  count

`count` is a positive integer. Default: `50`.

## Description

When a search does not supply `mv_matchlimit`, Interchange uses
`MV_DEFAULT_MATCHLIMIT` as the match limit; if that is unset it falls back to
the built-in default of `50`. The resolved value controls how many matches make
up one page of results before "more" links appear.

The exact fallback in the code is
`int($val) || $::Variable->{MV_DEFAULT_MATCHLIMIT} || 50`.

## Examples

Show 20 results per page by default:

    Variable  MV_DEFAULT_MATCHLIMIT  20

## See also

[MV_DEFAULT_SEARCH_TABLE](MV_DEFAULT_SEARCH_TABLE.md), the
[search](../guides/search.md) guide (which documents the per-search
`mv_matchlimit`).

## Source

Consumed in `lib/Vend/Scan.pm` via `$::Variable->{MV_DEFAULT_MATCHLIMIT}`.
