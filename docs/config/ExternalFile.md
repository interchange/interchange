# ExternalFile

Sets the path of the file Interchange writes when [External](External.md) export
is enabled. Reach for it to place the shared structure file where your external
programs can read it.

**Scope:** global (`interchange.cfg`)

## Syntax

    ExternalFile  filename

A single file path, resolved relative to the Interchange root. Default:
`external.structure` in the global run directory ([RunDir](RunDir.md)).

## Description

When [External](External.md) is enabled, Interchange dumps the exported global
and catalog values (selected by [ExternalExport](ExternalExport.md)) to this
file at catalog configuration time and sets its mode to `0644`
(`lib/Vend/Config.pm`). The bundled `Vend/External.pm` reads the file back for
consumers in other languages.

The path may also be overridden at read time by the `EXT_INTERCHANGE_FILE`
environment variable set by the external consumer (`lib/Vend/External.pm`); the
directive sets the default the Interchange daemon writes to.

`ExternalFile` has no effect unless [External](External.md) is enabled.

## Examples

Write the structure file to a known location, in `interchange.cfg`:

```
External yes
ExternalFile /tmp/external
```

## Notes

Choose a path both the Interchange daemon (which writes the file) and the
external program (which reads it) can access. On a typical install the default
lives at `RunDir/external.structure`.

## See also

[External](External.md), [ExternalExport](ExternalExport.md),
[RunDir](RunDir.md), the [sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_root_dir` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Config.pm` (dump) and `lib/Vend/External.pm`
(`$Global::ExternalFile`).
