# PageDir

Names the directory that holds a catalog's Interchange pages. Reach for it to
serve pages from a directory other than the default `pages`, including switching
by locale.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    PageDir  directory

A single relative directory (an absolute path is rejected), resolved against the
catalog root. Default: `pages`.

## Description

When Interchange serves a page, `lib/Vend/Util.pm` reads the requested page file
from `PageDir` (falling back to any [TemplateDir](TemplateDir.md) locations). The
directory is always taken relative to the catalog root.

Because the value can be varied per locale through the [Locale](Locale.md)
directive, `PageDir` is a convenient hook for internationalization: point each
locale at its own tree of translated pages.

## Examples

Serve pages from an `html` directory instead of `pages` (in `catalog.cfg`):

```
PageDir html
```

Use a different page tree per locale:

```
# Default at startup
PageDir english

# Locale-dependent directories
Locale fr_FR PageDir francais
Locale en_US PageDir english
```

## See also

[TemplateDir](TemplateDir.md), [PageTables](PageTables.md),
[Locale](Locale.md), the [templating](../guides/templating.md) and
[internationalization](../guides/internationalization.md) guides.

## Source

Parsed by `parse_relative_dir` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{PageDir}` in `lib/Vend/Util.pm`.
