# SessionDB

Names the database or server that holds sessions when
[SessionType](SessionType.md) is `DBI` or `Redis`. Reach for it only with those
backends; file and DBM sessions use [SessionDatabase](SessionDatabase.md)
instead.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SessionDB  target

A single token whose meaning depends on the session type:

- with `SessionType DBI`, the name of an Interchange
  [Database](Database.md) table to store sessions in;
- with `SessionType Redis`, the Redis server address (for example
  `127.0.0.1:6379`).

Default: empty. This directive has no effect for the `File`, `NFS`, `GDBM`, or
`DB_File` session types.

## Description

For `DBI` sessions, Interchange ties the session hash to `Vend::SessionDB`,
which stores each session as a row in the named table. The table must already be
defined as a catalog database and must live in an engine with row-level locking
(SQLite is rejected).

For `Redis` sessions, the value is passed to `Vend::SessionRedis` as the server
to connect to.

## Examples

SQL sessions in a table named `sessions`:

```
SessionType DBI
SessionDB   sessions
```

Redis sessions on a remote server:

```
SessionType Redis
SessionDB   10.0.0.5:6379
```

## Notes

DBI sessions add a database read and write to every request. Prefer the default
file sessions unless you specifically need shared session storage that file or
NFS sessions cannot provide.

## See also

[SessionType](SessionType.md), [SessionDatabase](SessionDatabase.md),
[SessionDBCompression](SessionDBCompression.md),
[SessionExpire](SessionExpire.md), [Database](Database.md), the
[sessions](../guides/sessions.md) guide.

## Source

Stored unparsed (`undef` parser) in `lib/Vend/Config.pm`. Consumed in
`lib/Vend/Session.pm` (`DBI` and `Redis` entries of `%Session_class`), which tie
to `lib/Vend/SessionDB.pm` or `lib/Vend/SessionRedis.pm`.
