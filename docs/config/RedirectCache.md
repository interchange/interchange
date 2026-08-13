# RedirectCache

Names a directory into which Interchange writes the static output of pages
that the web server redirected to it because a static file was missing.
Reach for it to have Interchange generate static HTML the web server can
serve directly on subsequent hits.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    RedirectCache  DIRECTORY

A directory path stored verbatim (no parser -- the raw string is kept).
Default: empty (the feature is off).

## Description

Together with the global [AcceptRedirect](AcceptRedirect.md) directive,
`RedirectCache` lets the web server route requests for missing static
pages to Interchange. When such a redirected request arrives (the web
server sets a redirect status), Interchange serves the page under a
temporary session and writes the produced HTML into the `RedirectCache`
directory at the request's path. The next time the same URL is requested,
the web server finds the now-existing static file and serves it directly,
bypassing Interchange.

Redirected requests use a temporary session, and the standard scratch
defaults `mv_no_count` and `mv_no_session_id` are forced so the written
page carries no session-specific URLs. If Interchange cannot find the
requested page, the usual `missing` special page is shown and nothing is
written to the cache directory.

The directory is consumed in `lib/Vend/Dispatch.pm` (which detects the
redirect and enables the write) and in `lib/Vend/Server.pm`, which builds
the output filename as `RedirectCache . path_info`.

## Examples

Cache generated pages into the web server's document root (in
`catalog.cfg`, with the matching global directive in `interchange.cfg`):

```
# interchange.cfg
AcceptRedirect Yes
```

```
# catalog.cfg
RedirectCache /var/www/html
```

A redirected request for `/catalog/specials.html` is rendered once by
Interchange and saved as `/var/www/html/catalog/specials.html`.

## Notes

Because the produced files are served statically afterward, they will not
update when catalog data changes; clear the cache directory when content
changes, or reserve this feature for genuinely static pages.

## See also

[AcceptRedirect](AcceptRedirect.md), [ScratchDefault](ScratchDefault.md),
[SpecialPage](SpecialPage.md), the
[performance](../guides/performance.md) guide.

## Source

Stored unparsed by `catalog_directives()` in `lib/Vend/Config.pm`;
consumed in `lib/Vend/Dispatch.pm` and `lib/Vend/Server.pm`.
