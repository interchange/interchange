# DirectoryIndex

Names the default page Interchange tries when a request maps to a directory
rather than a specific page. Reach for it to make a URL ending in a directory
path resolve to a known page inside that directory.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    DirectoryIndex  filename

A single page name (without the page-directory prefix or `.html` suffix, in the
usual Interchange style). Default: empty (no directory index is attempted).

## Description

When Interchange cannot find the requested page, and `DirectoryIndex` is set, it
appends the configured filename to the requested path (adding a slash if the
path is non-empty) and tries to read that page. For a request to `manuals/`
with `DirectoryIndex index.html`, Interchange looks for `manuals/index.html`.

The fallback runs after the normal page lookup and the on-the-fly flypage
attempt have failed, in `readin`/page display (`lib/Vend/Page.pm`). The
directory-index name is also substituted for an empty path when building URLs
in `lib/Vend/Dispatch.pm`.

This directive sets the default page for directories other than the catalog
entry point. It does not make the bare catalog URL show an index page; use
[SpecialPage](SpecialPage.md) (the `catalog` special page) for the entry point.

## Examples

Serve `index.html` as the default page inside any directory (this is the value
shipped in the strap demo `catalog.cfg`):

```
DirectoryIndex  index.html
```

## Notes

The name was borrowed from the Apache `DirectoryIndex` directive, but
Interchange accepts only a single filename -- there is no list of candidates
tried in order.

## See also

[SpecialPage](SpecialPage.md), [PageDir](PageDir.md),
[HTMLsuffix](HTMLsuffix.md), the [templating](../guides/templating.md) guide.

## Source

Stored as a raw string (no parser) from `catalog_directives()` in
`lib/Vend/Config.pm`; consumed in `lib/Vend/Page.pm` (`$Vend::Cfg->{DirectoryIndex}`)
and `lib/Vend/Dispatch.pm`.
