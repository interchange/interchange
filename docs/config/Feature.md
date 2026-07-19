# Feature

Installs a named *feature* -- a reusable bundle of configuration and files --
into the current catalog. Reach for it to add a self-contained piece of
functionality (a poll, a widget, a set of pages) without hand-copying its
config and assets.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Feature  FEATURE_NAME

A single feature name, resolved to a subdirectory of the same name under the
global [FeatureDir](FeatureDir.md). Default: empty (no features installed).

## Description

A feature is a directory of files that together add one capability to a
catalog. When Interchange reads a `Feature` line it locates
`FeatureDir/FEATURE_NAME` and processes its contents by file type:

- `*.global` files are read as global configuration (once per server, even if
  several catalogs request the same feature);
- `*.init` files are queued as initialization run for the catalog;
- `*.uninstall` files hold removal instructions;
- any other plain files are treated as `catalog.cfg` fragments and included
  inline at the point of the `Feature` directive;
- subdirectories are copied into the catalog tree.

If the named feature directory does not exist, Interchange logs a configuration
warning and skips it rather than aborting.

The directive is evaluated while the catalog configuration is parsed, so the
config fragments a feature contributes take effect as though they had been
written into `catalog.cfg` at that spot.

## Examples

Install the `quickpoll` feature in `catalog.cfg`:

```
Feature quickpoll
```

Interchange reads `FeatureDir/quickpoll/`, folds its catalog-config files into
the current configuration, and copies any bundled directories into the catalog.

## Notes

Because a feature can drop `*.global` files and copy directories, install
features from trusted sources only. The location searched is set by
[FeatureDir](FeatureDir.md).

## See also

[FeatureDir](FeatureDir.md), [Require](Require.md),
[Capability](Capability.md), [Database](Database.md).

## Source

Parsed by `parse_feature` in `lib/Vend/Config.pm`, which globs the feature
directory, sorts files by suffix, unshifts catalog-config files onto the
include list, and schedules global/init/copy work.
