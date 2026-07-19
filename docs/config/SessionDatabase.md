# SessionDatabase

Sets the filesystem location Interchange uses for file-based and DBM-based
sessions. Reach for it to move the session store off the default `session`
directory, or to point several catalogs at a shared session area.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SessionDatabase  directory

A single directory path, taken relative to the catalog root (an absolute path
is not accepted for this directive). Default: `session`.

## Description

For the default `File` (and `NFS`) [SessionType](SessionType.md), this names the
base directory that holds one file per session, hashed into subdirectories
according to [SessionHashLevels](SessionHashLevels.md) and
[SessionHashLength](SessionHashLength.md).

For the DBM session types the value is a base filename to which a suffix is
added: `GDBM` appends `.gdbm` and `DB_File` appends `.db`. The `DBI` and `Redis`
types ignore this directive and use [SessionDB](SessionDB.md) instead.

Multiple catalogs, or multiple Interchange servers sharing an NFS filesystem,
can point `SessionDatabase` at the same location to share sessions. The value is
read at configuration time.

## Examples

Store sessions in a directory named `session-data` under the catalog root:

```
SessionDatabase session-data
```

The strap demo sets it relative to the cache directory when one is configured:

```
SessionDatabase __CACHEDIR__/session
```

## See also

[SessionType](SessionType.md), [SessionDB](SessionDB.md),
[SessionLockFile](SessionLockFile.md),
[SessionHashLevels](SessionHashLevels.md),
[SessionHashLength](SessionHashLength.md),
[SessionExpire](SessionExpire.md), the [sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_relative_dir` in `lib/Vend/Config.pm`. Consumed in
`lib/Vend/Session.pm` (`%Session_class` tie calls) and, for file sessions,
`lib/Vend/SessionFile.pm`.
