# ConfigAllBefore

Names configuration files that Interchange reads for *every* catalog, before
that catalog's own configuration files. Reach for it to force server-wide
settings, presets, or defaults ahead of anything a catalog defines.

**Scope:** global (`interchange.cfg`)

## Syntax

    ConfigAllBefore  config_file ...

A whitespace-separated list of config files, each made absolute against the
Interchange root. The directive accumulates. Default: `catalog_before.cfg`.

## Description

At the start of each catalog's configuration, Interchange prepends the existing
files named by `ConfigAllBefore` (those that exist are included; missing ones
are silently skipped) to that catalog's include list, so they are processed
before the catalog's own `catalog.cfg` and other files. Because they run first,
their settings can be overridden by the catalog, making this the place for
defaults you want every catalog to start from.

A per-catalog `$ConfDir/<catalogname>.before` file is also processed at this
point, alongside the `ConfigAllBefore` files.

## Examples

Apply shared presets before every catalog, in `interchange.cfg`:

```
ConfigAllBefore set_actions.cfg set_variables.cfg
```

## See also

[ConfigAllAfter](ConfigAllAfter.md), [Catalog](Catalog.md),
[ConfDir](ConfDir.md), the [configuration](../guides/configuration.md) guide.

## Source

Parsed by `parse_root_dir_array` in `lib/Vend/Config.pm` (stored in
`@Global::ConfigAllBefore`); prepended to each catalog's include list in
`lib/Vend/Config.pm`.
