# DumpStructure

Writes the parsed data structure of the server and of each catalog to
`.structure` files at configuration time, so you can inspect how every directive
resolved. Reach for it to confirm what a directive actually evaluated to after
includes, variables, and defaults were applied.

**Scope:** global (`interchange.cfg`)

## Syntax

    DumpStructure  yes|no

A yes/no boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default:
`No`.

## Description

When enabled, Interchange dumps the parsed configuration to text files as it
reads each configuration. For a catalog named `standard`, it writes
`standard.structure` relative to that catalog's run/root directory; the global
server structure is written alongside the global configuration
(`lib/Vend/Config.pm` calls `dump_structure` in `lib/Vend/Util.pm`). Each file
is a `Data::Dumper` rendering of the internal configuration hash, so you can read
off the effective value of any directive.

The dump happens at (re)configuration time, not per request, so it reflects the
configuration the running server is using.

## Examples

Enable structure dumps in `interchange.cfg` (this line is present, commented,
in the shipped `interchange.cfg.dist`):

```
DumpStructure Yes
```

After a restart, look for `interchange.structure` next to your global
configuration and `<catalogname>.structure` under each catalog root.

## See also

[DumpAllCfg](DumpAllCfg.md), [DataTrace](DataTrace.md),
[DebugFile](DebugFile.md), the
[logging-debugging](../guides/logging-debugging.md) and
[configuration](../guides/configuration.md) guides.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Config.pm` (`$Global::DumpStructure`), which calls `dump_structure`
in `lib/Vend/Util.pm`.
