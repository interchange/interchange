# region

Iterate a result set over a body of ITL, resolving prefix sub-tags for each
row. `[region]` is the low-level list engine that [loop](loop.md),
[query](query.md), and [search-region](search-region.md) are built on; reach
for it directly when you already have a search object (or want `[region]` to run
a one-click search) and need full control over the list prefix.

## Syntax

    [region search="se=shirt/sf=description"]
    [item-code]: [item-field description]
    [/region]

Container tag (has an end tag). The body is a looping region interpolated once
per matched row.

## Attributes

| Attribute     | Default | Description |
|---------------|---------|-------------|
| `search`      | none    | A one-click search specification to run for the rows. |
| `object`      | none    | A pre-built search/result object to iterate (from Perl or another tag). |
| `label`       | none    | Name under which the search result is cached in the session. |
| `prefix`      | `item`  | Sub-tag prefix used inside the body (`[item-code]`, `[item-field ...]`). |
| `list_prefix` | none    | Overrides the `[list]` wrapper sub-tag name. |
| `more`        | none    | Enable "more" (paginated) result handling. |
| `ml`          | none    | Match limit per page (drives `[more-list]`). |
| `md`          | none    | More decade — page-link grouping size. |
| `query`       | none    | Query string recorded for the more/cache key. |

Positional order: none (`PosNumber 0`).

Aliases: `args`, `params`, and `search` all map to the canonical `arg`
attribute; in practice pass the search specification as `search`.

## Description

`[region]` obtains a result object one of three ways, in priority order:

1. If `object` is supplied, it iterates that object directly — no search is run.
   This is how [loop](loop.md) and [query](query.md) hand their rows to the
   engine.
2. If `search` is supplied (or a "more" pagination request is in progress), it
   runs that search like a one-click search and iterates the matches.
3. Otherwise it reuses the last search stored under `label`, or performs a
   search from the current CGI parameters.

It then walks the result set, interpolating the body once per row. Row values
are reached through prefix sub-tags whose prefix defaults to `item`:
`[item-code]` for the key, `[item-field col]` for a products-table column,
`[item-param col]` for a returned column of the row, and the rest of the
looping-tag namespace. Wrapper sub-tags `[on-match]`/`[no-match]` and
`[more-list]` are recognized inside the region. See
[templating](../guides/templating.md) for the complete sub-tag model shared by
all looping tags.

## Examples

Run a search and iterate its matches with the default `item` prefix:

    [region search="se=Ergo/sf=description"]
    [item-code]: [item-field description]
    [/region]

Change the prefix so the region can nest inside another list without sub-tag
name collisions:

    [region prefix=res search="se=os28/sf=sku"]
    [res-increment]. [res-field description]
    [/region]

## Notes

For everyday work prefer the tag written for your data source:
[loop](loop.md) for lists and arrays, [query](query.md) for SQL,
[search-region](search-region.md) for searches. They all delegate to
`[region]`, so anything documented here about prefixes and sub-tags applies to
them too.

## See also

- [loop](loop.md), [query](query.md), [search-region](search-region.md),
  [item-list](item-list.md), [search](search.md)
- Concepts: [templating](../guides/templating.md),
  [search](../guides/search.md)

## Source

Defined in `code/SystemTag/region.coretag`. Implemented by
`Vend::Interpolate::region`.
