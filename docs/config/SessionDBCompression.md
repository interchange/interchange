# SessionDBCompression

Enables transparent compression of session data stored in DBI or Redis session
backends. Reach for it to shrink large session rows -- for example carts with
many line items or heavy scratch data -- at the cost of some CPU per request.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SessionDBCompression  ALGORITHM

A single word naming the compression algorithm: `Zstd`, `Gzip`, or `Brotli`.
Default: empty (no compression). The chosen algorithm's Perl module
(`IO::Compress::Zstd`, `IO::Compress::Gzip`, or `IO::Compress::Brotli`) must be
installed.

## Description

When set, `Vend::SessionDB` (DBI sessions) and `Vend::SessionRedis` (Redis
sessions) compress the serialized session before storing it and decompress it on
retrieval, using `Vend::Util::Compress`. The stored bytes are opaque; the
compression is invisible to the rest of Interchange.

This directive only affects the database-backed session types. File, NFS, GDBM,
and DB_File sessions store data uncompressed and ignore it.

## Examples

Compress DBI sessions with Zstandard:

```
SessionType          DBI
SessionDB            sessions
SessionDBCompression Zstd
```

Compress Redis sessions with gzip:

```
SessionType          Redis
SessionDB            127.0.0.1:6379
SessionDBCompression Gzip
```

## Notes

The algorithm name is case-sensitive and must match one of the supported
values. Choose an algorithm whose module is present on the server, or session
reads and writes will error.

## See also

[SessionType](SessionType.md), [SessionDB](SessionDB.md),
[SessionExpire](SessionExpire.md), the [sessions](../guides/sessions.md) guide.

## Source

Stored unparsed (`undef` parser) in `lib/Vend/Config.pm`. Consumed in
`lib/Vend/SessionDB.pm` and `lib/Vend/SessionRedis.pm` (`STORE`/`FETCH`), which
call `compress`/`uncompress` from `lib/Vend/Util/Compress.pm`.
