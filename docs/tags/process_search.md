# process_search

Generates the URL of the catalog's search action — the classic `action`
target for a search form. `[process-search]` is an **extended alias**:
the parser rewrites it in place to

    [area href=search]

so it is [area](area.md) preset to the `search` action page.

## Syntax

    [process-search]

## Examples

    <form action="[process-search]" method="get">
    <input type="hidden" name="mv_session_id" value="[data session id]">
    <input name="mv_searchspec">
    <input type="submit" value="Search">
    </form>

The generated URL carries the session id and points at the
[search action](../guides/search.md), which runs the submitted `mv_*`
search parameters and displays the results page.

## Notes

Modern pages usually write `[area search]` directly; this alias survives
for compatibility with older catalogs.

## See also

[area](area.md), [page](page.md),
[The search engine](../guides/search.md)

## Source

Defined in the parser's built-in alias table (`%Alias`,
`lib/Vend/Parse.pm` ~line 251: `process_search => 'area href=search'`);
behavior implemented by [area](area.md).
