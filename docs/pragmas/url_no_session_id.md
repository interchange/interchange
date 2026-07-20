# url_no_session_id

Omits the session ID (and page count) from URLs that Interchange generates. Set
it when you want clean, session-free links from `[area]`, `[page]`, and related
tags — for example for cache-friendly or shareable URLs.

**Default:** off — generated URLs include the session ID unless a tag opts out.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma url_no_session_id

Page-wide, anywhere in an Interchange page:

    [pragma url_no_session_id]
    [pragma url_no_session_id 0]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma url_no_session_id]1[/tag]

This is a boolean pragma.

## Description

`vendUrl()` builds the URLs emitted by [area](../tags/area.md),
[page](../tags/page.md), and similar link tags. It normally appends the session
ID and a page-count value. When `url_no_session_id` is set (equivalent to passing
`no_session=1` to an individual tag), both the session ID and the page count are
left out of the generated URL.

Because it can be scoped to a block with `[tag pragma ...]`, you can strip session
IDs from just a section of links (for example, a set of links you expect to be
shared or cached) without changing link generation for the rest of the page.

## Examples

Generate session-free links catalog-wide. In `catalog.cfg`:

    Pragma url_no_session_id

Strip the session ID from one block of links only:

    [tag pragma url_no_session_id]1[/tag]
    <a href="[area href=index]">Home</a>
    <a href="[area href=about]">About</a>
    [tag pragma url_no_session_id]0[/tag]

## Notes

Removing the session ID from URLs affects session continuity for visitors without
cookies. Use it where session tracking through the URL is not required.

## See also

- [area](../tags/area.md), [page](../tags/page.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `vendUrl()` in
`lib/Vend/Util.pm`.
