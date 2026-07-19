# HammerLock

Sets the maximum number of seconds Interchange will wait to acquire a session
lock before deciding the lock is stale and forcing it. It is a safety valve
against a crashed process leaving a session locked forever.

**Scope:** global (`interchange.cfg`)

## Syntax

    HammerLock  INTERVAL

A time interval -- a bare number of seconds, or a phrase such as `1 minute` or
`30 secs`, which is converted to seconds. Default: `30`.

## Description

While one Interchange process holds a session locked, another process needing
the same session waits for the lock. `HammerLock` bounds that wait: it is the
number of seconds after which a held lock is treated as lost -- presumably left
behind by a process that died -- so the waiting process can break (hammer) the
lock and continue, and the stale lock file is cleaned up.

Reaching the limit is abnormal. Interchange logs when it force-breaks a lock;
if such messages appear in the error log, the server setup should be
investigated (an overloaded server, stuck processes, or a bad lock directory)
rather than the timeout simply raised.

## Examples

Extend the wait to one minute (`interchange.cfg`):

```
HammerLock 1 minute
```

The equivalent in seconds:

```
HammerLock 60
```

## Notes

`HammerLock` chiefly governs the shared-session locking used with
non-file session backends; with straightforward file-based sessions it rarely
comes into play. It exists to keep one wedged process from blocking others
indefinitely, not as a routine tuning knob.

## See also

[SessionType](SessionType.md), [SessionExpire](SessionExpire.md),
[AcrossLocks](AcrossLocks.md), [PIDcheck](PIDcheck.md), the
[sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_time` in `lib/Vend/Config.pm`; consumed by the session lock
code in `lib/Vend/Session.pm` (and `lib/Vend/SessionRedis.pm`), which uses
`$Global::HammerLock` as the maximum lock-wait time.
