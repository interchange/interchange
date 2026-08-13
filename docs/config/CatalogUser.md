# CatalogUser

Assigns a would-be Unix username to a catalog for permission checks on files
accessed by absolute path. Reach for it, together with
[NoAbsolute](NoAbsolute.md), to restrict which absolute files a catalog may
read or write based on file ownership and group.

**Scope:** global (`interchange.cfg`)

## Syntax

    CatalogUser  catalog_name  username

A catalog name followed by a Unix username. The directive accumulates, so one
line is written per catalog. Default: empty (no per-catalog user assigned).

## Description

This directive is only honored when [NoAbsolute](NoAbsolute.md) is enabled.
File access itself is still performed under the Interchange server's own Unix
user -- the `CatalogUser` value drives an additional "would-be" permission
check, not an identity change.

When `NoAbsolute` is on, Interchange permits a catalog to access a file by
absolute path when either:

- the path points inside the catalog directory or a configured
  [TemplateDir](TemplateDir.md); or
- the catalog's `CatalogUser` owns the file, or belongs to a group that may
  read it (the analogous test applies for write access).

## Examples

Assign users to two catalogs in `interchange.cfg`:

```
NoAbsolute Yes

CatalogUser  foundation  joe
CatalogUser  reports     jane
```

## See also

[NoAbsolute](NoAbsolute.md), [TemplateDir](TemplateDir.md),
[AllowGlobal](AllowGlobal.md), the [security](../guides/security.md) guide.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm` (stored in
`$Global::CatalogUser`); consumed by the absolute-path permission checks in
`lib/Vend/File.pm`.
