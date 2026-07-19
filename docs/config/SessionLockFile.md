# SessionLockFile

Names the lock file Interchange uses to serialize access to file and DBM
sessions. Reach for it when several catalogs or servers share a session store
and must coordinate through a common lock.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SessionLockFile  filename

A single filename, relative to the catalog root or absolute. Default:
`etc/session.lock`.

## Description

The `GDBM`, `DB_File`, and default `File` session types take an exclusive lock
on this file before opening a session, so that only one process manipulates the
session store at a time. The `DBI` and `Redis` types do their own locking and do
not use this file.

When several catalogs share one [SessionDatabase](SessionDatabase.md), point
them at the same `SessionLockFile` so writes are serialized across all of them.
The path may be absolute if the lock file lives outside the catalog tree.

## Examples

Use a lock file alongside a shared session store:

```
SessionDatabase  /var/interchange/session
SessionLockFile  /var/interchange/session.lock
```

## See also

[SessionDatabase](SessionDatabase.md), [SessionType](SessionType.md),
[SessionDB](SessionDB.md), [SessionExpire](SessionExpire.md), the
[sessions](../guides/sessions.md) guide.

## Source

Stored unparsed (`undef` parser) in `lib/Vend/Config.pm`. Consumed in
`lib/Vend/Session.pm` (`open_session`, `close_session`), which opens and locks
the file when the session type requires locking.
