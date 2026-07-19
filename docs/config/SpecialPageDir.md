# SpecialPageDir

Names the directory that holds a catalog's special pages -- the fallback error
and system pages Interchange serves when a request cannot be satisfied normally.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SpecialPageDir  DIRECTORY

`DIRECTORY` is a single directory path (stored as given, no parser). It is
always taken relative to the catalog root. Default: `special_pages`.

## Description

When Interchange needs a special page (for example the `missing` or `violation`
page from [SpecialPage](SpecialPage.md)) and no ordinary page satisfies the
request, it looks for the page under `SpecialPageDir`. Because this directive
can also be set within a [Locale](Locale.md) block, you can supply a different
set of special pages per locale.

## Examples

Keep special pages under `pages/special` instead of the default:

```
SpecialPageDir pages/special
```

## Notes

The path is always interpreted relative to the catalog root, even if written
without a leading directory component.

## See also

[SpecialPage](SpecialPage.md), [PageDir](PageDir.md),
[DirectoryIndex](DirectoryIndex.md), [Locale](Locale.md).

## Source

Stored verbatim (no parser) from the `catalog_directives()` table in
`lib/Vend/Config.pm` as `$Vend::Cfg->{SpecialPageDir}`; consulted during special
page lookup.
