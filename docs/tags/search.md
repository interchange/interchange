# search

Run a search against a catalog database and set up its results for display.
This is the tag form of the built-in `search` form action: it performs the
query, stores the result set in the session, and selects the results page.

## Syntax

    [search]
    [search "se=shirt/sf=description"]

Standalone tag (no end tag). The tag returns `1`; its useful effect is the
search it performs and the result object it stores, not its output. Pair it
with [search-region](search-region.md) or [item-list](item-list.md) to render
the matches.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `search`  | none    | An optional search specification. |

Positional order: `search`.

The tag declares `addAttr`, so additional `mv_*` search parameters may be
passed as attributes.

## Description

`[search]` maps to `Vend::Page::do_search`, the same routine invoked when a
form is submitted with `mv_action=search` (or through a `search/...` URL). It:

1. Reads the search parameters — the `mv_*` variables such as
   `mv_searchspec`, `mv_search_field`, `mv_search_file`, and `mv_matchlimit` —
   from the current form submission (the CGI values).
2. Performs the search, producing a result set.
3. Records it as the session's last search and stores the result object so the
   results page can iterate it.
4. Sets `mv_nextpage` to the search's configured results page, or the catalog's
   special `search` page if none was named.

Because the search terms come from the submitted form variables, `[search]` is
normally reached through a search form's action rather than typed on a page.
The most common way to display results is not this tag at all but the
[search-region](search-region.md) container, or an [item-list](item-list.md) on
the results page.

## Examples

A minimal search form. Submitting it triggers the `search` action, which runs
the same routine this tag wraps:

    <form action="[area search]" method="post">
      <input type="hidden" name="mv_search_file" value="products">
      <input type="text" name="mv_searchspec">
      <input type="submit" value="Search">
    </form>

Search inline and immediately iterate the matches with
[search-region](search-region.md), which is the more usual pattern for
one-page results:

    [search-region search="se=shirt/sf=description/ml=20"]
    [search-list]
    [item-code]: [item-field description]<br>
    [/search-list]
    [/search-region]

## Notes

The positional `search` argument is only honored as a full parameter hash when
called internally; when a plain string is passed, `do_search` falls back to the
CGI search variables. For inline, self-contained searches prefer
[search-region](search-region.md), which accepts a search specification string
directly.

## See also

- [search-region](search-region.md), [loop](loop.md),
  [item-list](item-list.md)
- [area](area.md), [page](page.md)
- Concepts: [search](../guides/search.md),
  [templating](../guides/templating.md)

## Source

Defined in `code/SystemTag/search.coretag`. Implemented by
`Vend::Page::do_search`.
