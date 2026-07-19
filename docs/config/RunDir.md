# RunDir

Names the directory where Interchange keeps runtime control files -- the
server-wide reconfigure, restart, and jobs-queue flags and status files.
Reach for it to place these transient files where you want them (the
equivalent of `/var/run` for Interchange).

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    RunDir  DIRECTORY

### Global

A single directory (`parse_root_dir`); a relative path is made absolute
against the Interchange root, trailing slashes stripped. Default:
`$Global::RunDir` if already set, otherwise `etc`.

### Catalog

A single relative directory (`parse_relative_dir`); an absolute path is
rejected, and the path is resolved against the catalog root. Default:
empty.

## Description

### Global

The global `RunDir` is where the running server drops and looks for its
control files: the `reconfig` and `restart` flag files that the
`interchange` control commands write, the `jobsqueue` file for scheduled
[Jobs](Jobs.md), the PID file, the dumped global structure (see
[DumpStructure](DumpStructure.md)), and per-mode status files. The control
tooling in `lib/Vend/Control.pm` and the reconfigure path in
`lib/Vend/Config.pm` read and write these files here.

### Catalog

A catalog may set its own `RunDir` to hold that catalog's status files.
When set, Interchange checks the catalog's `RunDir` (in addition to the
global one) for status files in `lib/Vend/Control.pm`. If left empty, only
the global `RunDir` is used.

## Examples

Global -- keep runtime files under `var/run` of the Interchange
installation (in `interchange.cfg`):

```
RunDir var/run
```

Catalog -- give a catalog its own run directory (from the strap
`catalog.cfg`, where `__RUNDIR__` is substituted at catalog build time):

```
RunDir __RUNDIR__
```

## Notes

The global directory must be writable by the Interchange user, since the
control commands communicate with the running daemon by writing flag files
into it. The catalog-scope path must be relative; an absolute value raises
a configuration error.

## See also

[ConfDir](ConfDir.md), [ScratchDir](ScratchDir.md),
[PermanentDir](PermanentDir.md), [Jobs](Jobs.md),
[DumpStructure](DumpStructure.md), the
[configuration](../guides/configuration.md) and [jobs](../guides/jobs.md)
guides.

## Source

Parsed by `parse_root_dir` (global) and `parse_relative_dir` (catalog) in
`lib/Vend/Config.pm`; consumed in `lib/Vend/Control.pm` and
`lib/Vend/Config.pm`.
