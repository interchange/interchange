# Catalog

Registers a catalog -- a complete Interchange store or application -- with the
server, mapping its name, base directory, and web link-program path so requests
can reach it. This is one of the fundamental directives every running
Interchange installation needs.

**Scope:** global (`interchange.cfg`)

## Syntax

    Catalog  name  directory  script  [alias ...]

or, one attribute at a time:

    Catalog  name  key  value

A catalog (a directory tree containing at minimum a `catalog.cfg`; see the
[catalog-anatomy](../guides/catalog-anatomy.md) guide) is defined by:

- `name` -- the catalog's identifier, used in log and error messages. Use only
  letters, digits, hyphens, and underscores; lowercase is recommended.
- `directory` -- the filesystem base directory of the catalog. If it does not
  exist, or the required `catalog.cfg` is missing or unreadable, the catalog is
  skipped and not activated.
- `script` -- the `SCRIPT_NAME` (web path) of the link program by which the
  catalog is reached.
- optional `alias` values -- additional web paths that reach the same catalog,
  for example an SSL or members-only URL.

The script name must be unique among the CGI paths on the server unless
[FullUrl](FullUrl.md) is enabled, in which case a hostname may be prepended to
distinguish otherwise identical paths. Default: empty (no catalog defined).

## Description

`Catalog` is read at server startup (and on reconfigure). Each definition is
stored in `%Global::Catalog` and drives dispatch: an incoming request's script
name is matched against the registered catalogs to decide which one handles it.

The keyed form (`Catalog name key value`) sets one attribute of an
already-named catalog. Recognized keys include `directory`/`dir`, `script`,
`alias`/`aliases`, `base`, `global`, `fullurl`/`full`, and `directive`. The
`directive` key sets a catalog-specific configuration directive from the global
file, which is most useful for per-catalog [ErrorFile](ErrorFile.md) and
[DisplayErrors](DisplayErrors.md) settings.

A subcatalog -- a catalog sharing another's code base -- is defined with the
related [SubCatalog](SubCatalog.md) directive.

## Examples

Register a catalog in `interchange.cfg`:

```
Catalog simple /home/catalogs/simple /cgi-bin/ic/simple
```

Distinguish two same-named catalogs on different hosts with
[FullUrl](FullUrl.md):

```
FullUrl yes

Catalog simple1 /home/catalogs/simple1 www.company1.com/cgi-bin/ic/simple
Catalog simple2 /home/catalogs/simple2 www.company2.com/cgi-bin/ic/simple
```

Build the same definition verbosely, one key at a time:

```
Catalog simple  directory /home/catalogs/simple
Catalog simple  script    /cgi-bin/ic/simple
Catalog simple  alias     /simple
```

Set a catalog-specific directive from the global file:

```
Catalog simple  directive ErrorFile /var/log/interchange/simple-error.log
```

## Notes

The `makecat` catalog-creation helper inserts the `Catalog` line into
`interchange.cfg` automatically. If the catalog's `catalog.cfg` cannot be read,
the reported error can be misleading -- it may complain that the mandatory
[VendURL](VendURL.md) directive is undefined rather than naming the underlying
permissions problem.

## See also

[SubCatalog](SubCatalog.md), [FullUrl](FullUrl.md), [VendURL](VendURL.md),
[ConfigDatabase](ConfigDatabase.md), [CatalogUser](CatalogUser.md), the
[catalog-anatomy](../guides/catalog-anatomy.md) and
[installation](../guides/installation.md) guides.

## Source

Parsed by `parse_catalog` in `lib/Vend/Config.pm` (stored in
`%Global::Catalog`); consumed during request dispatch in
`lib/Vend/Dispatch.pm`.
