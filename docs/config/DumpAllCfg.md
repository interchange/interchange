# DumpAllCfg

Writes the fully expanded global server configuration to a file at startup, so
you can see the effective `interchange.cfg` with all included files merged in.
Reach for it to audit exactly what global configuration the server read.

**Scope:** global (`interchange.cfg`)

## Syntax

    DumpAllCfg  yes|no

A yes/no boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default:
`No`.

## Description

When enabled, Interchange writes the complete global configuration -- with any
`include` directives expanded -- to `allconfigs.cfg` in the global run
directory ([RunDir](RunDir.md)) during startup (`lib/Vend/Config.pm`). The dump
covers only the global server configuration; it does not include per-catalog
configuration. For catalog and server data structures, use
[DumpStructure](DumpStructure.md) instead.

## Examples

Dump the merged global configuration in `interchange.cfg`:

```
DumpAllCfg Yes
```

The file is written to `RunDir/allconfigs.cfg` (for a tarball install, typically
`/usr/local/interchange/etc/allconfigs.cfg`).

## Notes

`DumpAllCfg` was previously named `OutputAllCfg`; it was renamed to match
[DumpStructure](DumpStructure.md). The old name is no longer recognized.

## See also

[DumpStructure](DumpStructure.md), [RunDir](RunDir.md),
[ConfigDir](ConfigDir.md), the
[configuration](../guides/configuration.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Config.pm` (`$Global::DumpAllCfg`, writing `RunDir/allconfigs.cfg`).
