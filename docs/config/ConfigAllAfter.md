# ConfigAllAfter

Names configuration files that Interchange reads for *every* catalog, after all
of that catalog's own configuration files. Reach for it to catch user
configuration errors, supply missing values, or force your settings over a
catalog's.

**Scope:** global (`interchange.cfg`)

## Syntax

    ConfigAllAfter  config_file ...

A whitespace-separated list of config files, each made absolute against the
Interchange root. The directive accumulates. Default: `catalog_after.cfg`.

## Description

At the end of each catalog's configuration, Interchange appends the existing
files named by `ConfigAllAfter` (those that exist are included; missing ones
are silently skipped) to that catalog's include list, so they are processed
after the catalog's own `catalog.cfg` and other files. Because they run last,
their settings take precedence, making this the place for values you want to
enforce over whatever a catalog configured.

A per-catalog `$ConfDir/<catalogname>.after` file is also processed at this
point, alongside the `ConfigAllAfter` files.

## Examples

Enforce shared settings after every catalog, in `interchange.cfg`:

```
ConfigAllAfter check_actions.cfg check_variables.cfg
```

## See also

[ConfigAllBefore](ConfigAllBefore.md), [Catalog](Catalog.md),
[ConfDir](ConfDir.md), the [configuration](../guides/configuration.md) guide.

## Source

Parsed by `parse_root_dir_array` in `lib/Vend/Config.pm` (stored in
`@Global::ConfigAllAfter`); appended to each catalog's include list in
`lib/Vend/Config.pm`.
