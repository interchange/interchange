# SessionType

Selects the storage backend Interchange uses for user sessions. Reach for it
when you want sessions kept somewhere other than the default local files -- for
example in a shared DBM file, an SQL table, Redis, or on an NFS-mounted volume.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SessionType  TYPE

A single word naming the session class. Recognized values are `File`, `NFS`,
`GDBM`, `DB_File`, `DBI`, and `Redis`. An unrecognized value falls back to
`File`. Default: `File`.

## Description

Interchange keeps per-visitor state -- the cart, values, scratch, and session
variables -- in a session store chosen by this directive. Each type ties the
in-memory session hash to a different backend:

- `File` -- one file per session under [SessionDatabase](SessionDatabase.md),
  hashed into subdirectories (see [SessionHashLevels](SessionHashLevels.md) and
  [SessionHashLength](SessionHashLength.md)). This is the default and gives the
  best performance and reliability in most setups.
- `NFS` -- like `File`, but uses `fcntl` locking so the session directory can
  live on an NFS-mounted filesystem shared by multiple servers.
- `GDBM` -- a single GDBM file at `SessionDatabase` with a `.gdbm` suffix.
- `DB_File` -- a single Berkeley DB file at `SessionDatabase` with a `.db`
  suffix.
- `DBI` -- an SQL table named by [SessionDB](SessionDB.md). Requires a database
  with row-level locking (SQLite is rejected because it has none).
- `Redis` -- a Redis server whose address is given by
  [SessionDB](SessionDB.md).

The `GDBM`, `DB_File`, `DBI`, and `Redis` backends are only available if the
corresponding Perl support was detected when the daemon started. The file-based
and DBM types lock with [SessionLockFile](SessionLockFile.md).

`SessionType` is read at catalog configuration time; changing it requires a
restart or reconfigure.

## Examples

Use the default local-file sessions (this line is optional, since `File` is the
default):

```
SessionType File
```

Store sessions in an SQL table named `sessions`:

```
SessionType DBI
SessionDB   sessions
```

Store sessions in Redis running on the local host:

```
SessionType Redis
SessionDB   127.0.0.1:6379
```

## Notes

The default `File` type is recommended for most catalogs. DBI sessions add
database load on every request and require careful locking; the strap demo
ships them commented out.

## See also

[SessionDB](SessionDB.md), [SessionDatabase](SessionDatabase.md),
[SessionLockFile](SessionLockFile.md), [SessionExpire](SessionExpire.md),
[SessionDBCompression](SessionDBCompression.md),
[SessionHashLevels](SessionHashLevels.md),
[SessionHashLength](SessionHashLength.md), the
[sessions](../guides/sessions.md) guide.

## Source

Stored unparsed (`undef` parser) in `lib/Vend/Config.pm`
(`catalog_directives()`). Consumed in `lib/Vend/Session.pm`
(`%Session_class`, `open_session`), which dispatches to `lib/Vend/SessionFile.pm`,
`lib/Vend/SessionDB.pm`, or `lib/Vend/SessionRedis.pm`.
