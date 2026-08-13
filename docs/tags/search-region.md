# search-region

Run a search and iterate its result rows over the tag's body. It combines a
search and a display loop in one container, so you can present results inline on
any page without a separate results page or a prior `search` action.

## Syntax

    [search-region search="se=shirt/sf=description"] ... [/search-region]

Container tag (has an end tag; its body is the region template). The body is
processed once per matching row.

## Attributes

| Attribute      | Default        | Description |
|----------------|----------------|-------------|
| `arg`          | none           | The search specification string (the positional argument). |
| `search`       | none           | Alias for `arg`; the usual spelling. |
| `prefix`       | `item`         | Namespace prefix for the row sub-tags (for example `[item-code]`). |
| `list_prefix`  | `search-list`  | Name of the inner list region wrapper (`[search-list]...[/search-list]`). |

Positional order: `arg`.

Aliases: `args`, `params`, and `search` all map to `arg`.

The tag declares `addAttr`, so the full set of list/region options (`prefix`,
`list_prefix`, `more`, `sort`, and the `mv_*` search parameters) are read from
the attribute list.

## Description

`[search-region]` maps to `Vend::Interpolate::tag_search_region`. It takes the
search specification from `arg`/`search`, performs the search, and then renders
its body as a list region over the result rows — the same looping machinery
used by [loop](loop.md) and [item-list](item-list.md).

### The search specification

The `search` string is Interchange's compact search syntax, a
slash-separated list of two-letter `mv_*` codes. Common ones:

- `se=` search string (`mv_searchspec`)
- `sf=` search field(s) (`mv_search_field`)
- `fi=` file/table to search (`mv_search_file`)
- `ml=` match limit (`mv_matchlimit`)
- `co=1` coordinated multi-field search

### Row sub-tags

Inside the region, per-row data is available through the prefix namespace
(default `item`), for example `[item-code]`, `[item-field description]`,
`[item-increment]`, and the `[if-item-field ...]` conditionals. Wrap the
repeating part in `[search-list]...[/search-list]`; markup outside that inner
region (such as headers or "no matches" text) is emitted once. This is the
standard loop sub-tag model shared by all looping tags — see
[templating](../guides/templating.md) for the full list of `PREFIX-*` sub-tags
and the `[if-PREFIX-*]` conditionals.

## Examples

Search the `products` table and list matches:

    [search-region search="se=shirt/sf=description/ml=20"]
    [search-list]
    [item-code]: [item-field description] — [item-price]<br>
    [/search-list]
    [/search-region]

Add a numbered heading and a fallback when nothing matches, using the once-only
region outside `[search-list]`:

    [search-region search="se=[cgi q]/sf=description"]
    <p>Results:</p>
    [search-list]
    [item-increment]. [item-field description]<br>
    [/search-list]
    [/search-region]

## Notes

`[search-region]` is the inline alternative to the [search](search.md) action
plus a separate results page: it is self-contained and does not depend on
submitted form variables, since the specification is passed directly.

## See also

- [search](search.md), [loop](loop.md), [item-list](item-list.md)
- Concepts: [search](../guides/search.md),
  [templating](../guides/templating.md)

## Source

Defined in `code/SystemTag/search_region.coretag`. Implemented by
`Vend::Interpolate::tag_search_region`.
