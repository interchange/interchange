# ConfDir

Names the catalog's "config" directory, where Interchange keeps runtime control
and status files. Reach for it only if you need to relocate that directory from
its default.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ConfDir  directory_name

A single directory, relative to the catalog root (an absolute path is not
allowed). Default: `etc` (inside the catalog directory).

## Description

`ConfDir` sets the directory Interchange uses for a catalog's internal
control and status files -- for example the session lock file, per-catalog
`.before`/`.after` config fragments, and feature `init` files. It defaults to
`etc/` under the catalog root and rarely needs changing.

Do not confuse it with the similarly named [ConfigDir](ConfigDir.md) (the
include directory for the `<file` config notation) or [DirConfig](DirConfig.md)
(which loads directory files into a directive hash).

## Examples

Relocate the config directory in `catalog.cfg`:

```
ConfDir etc2
```

## See also

[ConfigDir](ConfigDir.md), [DirConfig](DirConfig.md),
[RunDir](RunDir.md), the [catalog-anatomy](../guides/catalog-anatomy.md) guide.

## Source

Parsed by `parse_relative_dir` in `lib/Vend/Config.pm` (stored as
`$Vend::Cfg->{ConfDir}`); consumed in `lib/Vend/Config.pm`,
`lib/Vend/Control.pm`, and elsewhere for per-catalog control files.
