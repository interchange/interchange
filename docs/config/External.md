# External

Enables Interchange to export selected global and catalog values to a file that
external programs (in PHP, Python, Ruby, and so on) can read to share sessions
and configuration. Reach for it when a non-Interchange application needs access
to Interchange session data or configuration.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    External  yes|no

A yes/no boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default:
`No` in both scopes.

## Description

When enabled, Interchange dumps selected information to the file named by
[ExternalFile](ExternalFile.md) at catalog (re)configuration time. The dump is a
Perl `Storable`/`Data::Dumper`-style memory image that the bundled
`Vend/External.pm` helper (loadable from other languages via a Perl bridge) can
read back.

The feature is gated in two stages:

### Global

`External Yes` in `interchange.cfg` must be set first to permit the feature at
all. It also selects which global values are exported through the global-scope
[ExternalExport](ExternalExport.md).

### Catalog

With the global flag on, `External Yes` in a catalog's `catalog.cfg` makes that
catalog write its own structure into the shared file, exporting the values named
by the catalog-scope [ExternalExport](ExternalExport.md). If a catalog sets
`External Yes` but the global directive is off, configuration warns that the
feature is not allowed and nothing is dumped (`lib/Vend/Config.pm`).

## Examples

Enable export both globally and per catalog. In `interchange.cfg`:

```
External yes
```

and in each participating `catalog.cfg`:

```
External yes
```

## Notes

The dump happens at configuration time, so external consumers see a snapshot as
of the last restart or reconfiguration. See [ExternalExport](ExternalExport.md)
for choosing exactly which values are written and [ExternalFile](ExternalFile.md)
for the output location.

## See also

[ExternalExport](ExternalExport.md), [ExternalFile](ExternalFile.md), the
[sessions](../guides/sessions.md) and [architecture](../guides/architecture.md)
guides.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm` (both directive tables);
consumed in `lib/Vend/Config.pm` (catalog config postprocess) and
`lib/Vend/External.pm`.
