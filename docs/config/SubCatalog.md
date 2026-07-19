# SubCatalog

Registers a subcatalog -- a catalog that shares another catalog's code base and
configuration, overriding only the directives that differ. Use it to run
several closely related storefronts from one set of pages without duplicating
everything.

**Scope:** global (`interchange.cfg`)

## Syntax

    SubCatalog  name  base  directory  script [alias ...]

The value is parsed the same way as [Catalog](Catalog.md) (parser type
`catalog`). Default: empty. The arguments are:

- `name` -- the new subcatalog's identifier.
- `base` -- the name of an existing [Catalog](Catalog.md) whose configuration
  the subcatalog inherits.
- `directory` -- the subcatalog's root directory; this may be the same
  directory as the base catalog.
- `script` -- the link-program web path by which the subcatalog is reached.
- optional `alias` values -- additional web paths that reach the subcatalog.

## Description

A subcatalog inherits the base catalog's configuration and code, then applies
its own `catalog.cfg`, which should contain only the directives that differ from
the base. Requests to the subcatalog's `script` path are dispatched to it just
like any catalog. Subcatalogs are mainly used to save memory when running
several variants of one catalog, or to build chained configurations.

The base catalog must be defined (with [Catalog](Catalog.md)) before, or
alongside, the `SubCatalog` line that references it.

## Examples

Define a base catalog and a subcatalog that shares its directory:

```
Catalog    simple    /home/catalogs/simple /cgi-bin/ic/simple
SubCatalog subsimple simple /home/catalogs/simple /cgi-bin/ic/subsimple
```

## See also

[Catalog](Catalog.md), [FullUrl](FullUrl.md), [Mall](Mall.md),
[Replace](Replace.md), the [catalog-anatomy](../guides/catalog-anatomy.md)
guide.

## Source

Parsed by `parse_catalog` in `lib/Vend/Config.pm` (stored in
`%Global::Catalog`); consumed during request dispatch in `lib/Vend/Dispatch.pm`.
