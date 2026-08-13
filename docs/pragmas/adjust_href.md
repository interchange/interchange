# adjust_href

Rewrites plain `<a href="page?parm=val">` links in HTML output into proper
Interchange URLs, automatically, for every HTML page. Set it when pages are
authored in an HTML editor and you want their relative links turned into valid
Interchange links without adding a tag to each page.

**Default:** off — link `href` values are output unchanged.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma adjust_href

Page-wide, anywhere in an Interchange page:

    [pragma adjust_href]
    [pragma adjust_href 0]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma adjust_href]1[/tag]

This is a boolean pragma.

## Description

When `adjust_href` is set and the response is HTML, `Vend::Server` passes the
whole body through the [adjust_href](../tags/adjust_href.md) tag before
sending it. That tag parses the HTML, finds `<a href>` links, and for any link
that does not begin with an absolute path or a `scheme:` prefix, rebuilds it as
an Interchange URL (equivalent to running the link through `[area]`), carrying the
query string over into the link's form parameters.

This lets an HTML editor edit pages and links and still produce valid Interchange
URLs, without the author writing `[area]` around every link.

The related [allow_for_users](allow_for_users.md) pragma changes how already-
adjusted, user-supplied links are handled during this rewrite.

## Examples

Turn on automatic link adjustment catalog-wide. In `catalog.cfg`:

    Pragma adjust_href

A hand-authored link in a page:

    <a href="somepage.html?parameter=value">link anchor</a>

is delivered as an Interchange URL such as:

    <a href="https://srv.example.com/cgi/link/somepage.html?parameter=value&id=x338Dbll">link anchor</a>

## Notes

Added in Interchange 5.12 (the whole-page rewrite in `Vend::Server` plus the
supporting tag). Links that already begin with an absolute path or a scheme are
left alone. The tag does not currently handle relative `../` paths.

## See also

- [allow_for_users](allow_for_users.md)
- [adjust_href](../tags/adjust_href.md) tag
- [area](../tags/area.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `respond()` in
`lib/Vend/Server.pm`, which calls the `adjust_href` tag in
`code/UserTag/adjust_href.tag`.
