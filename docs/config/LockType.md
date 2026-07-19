# LockType

Selects the file-locking method Interchange uses for its lock operations.
Reach for it when your locked files live on NFS, where `flock` may not work
and `fcntl` locking is required.

**Scope:** global (`interchange.cfg`)

## Syntax

    LockType  flock|fcntl|none

A single word, stored verbatim (no parser). Default: empty, which selects
`flock` behavior.

## Description

Interchange locks files (sessions, DBM tables, counters) to coordinate
concurrent server processes. `LockType` chooses the locking primitive:

- `flock` -- the default; the standard `flock(2)` advisory locking. Works
  well on local filesystems.
- `fcntl` -- `fcntl(2)` locking, needed on NFS. Both the NFS client and
  server must run the lock daemon (`lockd`). Matched case-insensitively.
- `none` -- disables locking entirely. Not recommended; use only to test
  whether locking is the cause of a system hang.

Any value other than `none` or something matching `fcntl` falls back to
`flock`, so an empty or unrecognized setting behaves as `flock`.

The directive is read at server startup and applies globally.

## Examples

Use `fcntl` locking for an NFS-mounted setup (put in `interchange.cfg`):

```
LockType fcntl
```

## Notes

If only your session directory is on NFS while the rest of Interchange is
local, you can instead set the per-catalog [SessionType](SessionType.md)
directive to `NFS`, which enables `fcntl` locking for sessions alone
without changing global locking.

## See also

[SessionType](SessionType.md), [SessionLockFile](SessionLockFile.md),
[HammerLock](HammerLock.md), the
[performance](../guides/performance.md) guide.

## Source

Stored raw (no parser) from the `global_directives()` table in
`lib/Vend/Config.pm`; the lock method is selected in
`Vend::File::set_lock_type` (`lib/Vend/File.pm`).
