# ScratchDir

Names the directory where Interchange writes transient working files --
cached searches, retired session IDs, and other short-lived scratch data.
Reach for it to relocate this temporary storage (for example onto faster or
larger disk).

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ScratchDir  DIRECTORY

A single relative directory (`parse_relative_dir`); an absolute path is
rejected, and the path is resolved against the catalog root. Default:
`tmp`. The directory is created during configuration if it does not exist.

## Description

`ScratchDir` is Interchange's per-catalog temporary-file area. Files it
holds include cached search results, retired (expired) session IDs, IP
access counters, staged import data, and temporary files used by shipping,
payment, and PGP processing. Many subsystems build paths beneath it --
`lib/Vend/Session.pm`, `lib/Vend/Ship.pm`, `lib/Vend/Order.pm`,
`lib/Vend/Payment.pm`, and `lib/Vend/Data.pm` among them -- so the
directory must be writable by the Interchange user.

Despite the name, this is distinct from *scratch variables* (see
[ScratchDefault](ScratchDefault.md)); `ScratchDir` is a filesystem
directory for working files.

## Examples

Use the default `tmp` directory under the catalog root (from the strap
`catalog.cfg`):

```
ScratchDir      tmp
```

Point it at a cache area, as the strap does when a cache directory is
configured (`__CACHEDIR__` is substituted at catalog build time):

```
ScratchDir      __CACHEDIR__/tmp
```

## Notes

The location is always relative to the catalog root; an absolute path
raises a configuration error. Because the directory holds session and
cache data, apply appropriate permissions (see
[ReadPermission](ReadPermission.md) and
[WritePermission](WritePermission.md)).

## See also

[ScratchDefault](ScratchDefault.md), [RunDir](RunDir.md),
[PermanentDir](PermanentDir.md), [CounterDir](CounterDir.md),
[SessionDatabase](SessionDatabase.md), the
[sessions](../guides/sessions.md) and [search](../guides/search.md) guides.

## Source

Parsed by `parse_relative_dir` in `lib/Vend/Config.pm` (created at config
time if absent); consumed across `lib/Vend/Session.pm`, `lib/Vend/Ship.pm`,
`lib/Vend/Order.pm`, `lib/Vend/Payment.pm`, and `lib/Vend/Data.pm`.
