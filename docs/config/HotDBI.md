# HotDBI

Names the catalogs whose DBI database connections should be kept open and cached
between page requests instead of being reconnected each time. Reach for it to
avoid per-request connection overhead in a persistent (preforked) server.

**Scope:** global (`interchange.cfg`)

## Syntax

    HotDBI  catalog[ catalog...]

Parsed as a set of catalog names: each named catalog is flagged. Names may span
several `HotDBI` lines and accumulate. Default: empty (no catalogs use hot
connections).

## Description

When a catalog is listed in `HotDBI`, Interchange does not disconnect that
catalog's DBI database handle when a table is closed at the end of a request:
the connection is left in the connection cache and reused by the next request
that needs it. For catalogs not listed, the handle is disconnected once its last
user closes.

Keeping the connection warm removes the cost of establishing a new database
connection on every request, which matters most under a long-lived server
process. The trade-off is that each server child holds an open database
connection for the life of the process, consuming a connection slot on the
database whether or not it is actively serving that catalog.

## Examples

Keep the `tutorial1` catalog's database connection warm (`interchange.cfg`):

```
HotDBI tutorial1
```

## Notes

`HotDBI` only affects DBI/SQL-backed tables. Because each preforked child holds
its own persistent connection, size your database's maximum-connection limit for
the number of Interchange servers. It is most useful with
[PreFork](PreFork.md)/[StartServers](StartServers.md) style persistence.

## See also

[Database](Database.md), [DatabaseAuto](DatabaseAuto.md),
[PreFork](PreFork.md), [MaxServers](MaxServers.md), the
[databases](../guides/databases.md) and [performance](../guides/performance.md)
guides.

## Source

Parsed by `parse_boolean` in `lib/Vend/Config.pm` (a hash keyed by catalog
name); consumed by `close_table` in `lib/Vend/Table/DBI.pm`, which skips the
disconnect when `$Global::HotDBI->{$Vend::Cat}` is true.
