# max_matches

Caps the number of rows a search may return, catalog-wide or per page. Reach for
it to bound the size of search result sets so a broad query cannot return an
unbounded number of matches.

**Default:** unset — no pragma-imposed cap (searches use their own
`mv_max_matches`, subject to other search defaults).

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma max_matches=500

Page-wide, anywhere in an Interchange page:

    [pragma max_matches 500]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma max_matches]500[/tag]

The value is a positive integer.

## Description

When a database search runs, Interchange sets the effective match limit to the
**lower** of the `max_matches` pragma and the search's own `mv_max_matches`
parameter. A value less than `1` is treated as unset (no pragma cap).

Because the lower of the two wins, an end user (or a search form) can further
restrict the result-set size with `mv_max_matches`, but cannot exceed the ceiling
you set with the pragma. This makes `max_matches` a safe upper bound that page
authors and site visitors cannot raise.

## Examples

Limit every search to at most 500 rows. In `catalog.cfg`:

    Pragma max_matches=500

A search requesting more is still capped:

    [search-region
      more=1
      search="
        se=shirt
        mv_max_matches=10000
      "
    ]
    ...
    [/search-region]

returns at most 500 rows despite the `mv_max_matches=10000` request.

## Notes

Added in Interchange 5.7. The cap is applied in the database search path; it
bounds the number of matches retained, working together with the search's own
`mv_max_matches` and `mv_matchlimit` parameters.

## See also

- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `search()` in
`lib/Vend/DbSearch.pm`.
