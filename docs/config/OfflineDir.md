# OfflineDir

Names the directory that holds the "offline" copies of database source files
used by the offline database-build process. Reach for it when you build tables
offline and want to keep the working copies somewhere other than the default.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    OfflineDir  directory

A single relative directory (an absolute path is rejected), resolved against the
catalog root. Default: `offline`.

## Description

The `offline` command-line utility rebuilds a catalog's database tables from
their source files without disturbing the running catalog. When no explicit
directory is given on its command line, the tool sets the catalog's product
directory to `OfflineDir` and reads the source files from there, as seen in
`scripts/offline`:

```perl
$Vend::Cfg->{ProductDir} = $directory || $Vend::Cfg->{OfflineDir};
```

The directive only names where those offline source files live; it has no effect
on a normally running catalog that is not being rebuilt offline.

## Examples

Keep offline build files under the catalog's own `offline` directory (the
default, shown for clarity in `catalog.cfg`):

```
OfflineDir offline
```

Use a separate staging directory under the catalog root:

```
OfflineDir build/offline
```

## See also

[ProductDir](ProductDir.md), [ConfDir](ConfDir.md), the
[databases](../guides/databases.md) guide.

## Source

Parsed by `parse_relative_dir` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{OfflineDir}` in `scripts/offline`.
