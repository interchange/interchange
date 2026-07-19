# TemplateDir

Names extra directories that Interchange searches for pages when a page is not
found in the catalog's own [PageDir](PageDir.md). Reach for it to share a common
set of template pages across catalogs, or to extend one catalog's page search
beyond its own tree.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    TemplateDir  directory ...

A shell-quoted list of directories. Each is appended to a search list, so
multiple lines accumulate. Default: empty (no fallback directories).

## Description

When Interchange looks up a page and does not find it under the catalog's
[PageDir](PageDir.md), it then searches the `TemplateDir` directories in order
and serves the first matching file. The same directories also count as allowed
locations for file access, so a page found there is readable even though it lies
outside the normal page tree.

The catalog list is searched before the global list: the effective order is the
current directory, then the catalog `TemplateDir` entries, then the global
`TemplateDir` entries.

### Global

In `interchange.cfg`, entries are made absolute against the Interchange server
root. Use the global scope for directories of default pages common to every
catalog on the server.

### Catalog

In `catalog.cfg`, entries are resolved against the catalog's own root and
validated as allowed files. Use the catalog scope to extend a single catalog's
page search.

## Examples

A shared default-pages directory for all catalogs (in `interchange.cfg`):

```
TemplateDir  /usr/local/interchange/default_pages
```

Several fallback directories for one catalog (in `catalog.cfg`):

```
TemplateDir  templates  ../common/pages
```

## See also

[PageDir](PageDir.md), [SpecialPageDir](SpecialPageDir.md),
[SpecialPage](SpecialPage.md), the [templating](../guides/templating.md) guide.

## Source

Parsed by `parse_root_dir_array` (global) and `parse_dir_array` (catalog) in
`lib/Vend/Config.pm`; consumed in `lib/Vend/Util.pm` during page lookup and in
`lib/Vend/File.pm` (`allowed_file`) via `$Global::TemplateDir` and
`$Vend::Cfg->{TemplateDir}`.
