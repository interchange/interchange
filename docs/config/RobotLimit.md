# RobotLimit

Caps how many pages a client may fetch in quick succession before
Interchange treats it as an abusive robot and locks it out. Reach for it to
blunt runaway crawlers and denial-of-service-style access patterns.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    RobotLimit  COUNT

A single integer (`parse_integer`). `0` disables the check. Default: `0`.

## Description

When `RobotLimit` is non-zero, Interchange counts a session's consecutive
page accesses. If more than `RobotLimit` pages are fetched without at least
a short pause between them, the client is locked out: the lockout routine
runs [LockoutCommand](LockoutCommand.md) (passing the client's IP) and
rewrites the catalog's [VendURL](VendURL.md) and [SecureURL](SecureURL.md)
to `http://127.0.0.1`, so generated links point the offender back at
itself. Administrative sessions are exempt.

The "short pause" that resets the access counter is 30 seconds, adjustable
with the [Limit](Limit.md) directive's `lockout_reset_seconds` setting.

`RobotLimit` also governs clients that get a fresh session on every hit
(never keeping one): it limits how many new sessions a single IP may be
assigned within a one-hour window. That window is set by `Limit`'s
`ip_session_expire`; once triggered, the lockout lasts one day by default,
adjustable with `Limit`'s `robot_expire`.

The counting and lockout logic live in `lib/Vend/Dispatch.pm` and
`lib/Vend/Session.pm`; the lockout itself is performed by `do_lockout` in
`lib/Vend/Error.pm`.

## Examples

Lock out a client after 100 rapid page accesses (from the strap
`catalog.cfg`):

```
RobotLimit  100
```

Combine with a firewall command that blocks the offending address:

```
# interchange.cfg
LockoutCommand /usr/local/bin/block-ip %s
```

## Notes

Set the limit above the number of pages any legitimate user would visit in
a short burst; too low a value locks out real customers. Well-behaved
crawlers should instead be classified with [RobotUA](RobotUA.md),
[RobotIP](RobotIP.md), or [RobotHost](RobotHost.md) so they simply run
without sessions rather than being locked out.

## See also

[LockoutCommand](LockoutCommand.md), [Limit](Limit.md),
[OrderLineLimit](OrderLineLimit.md), [RobotUA](RobotUA.md), the
[sessions](../guides/sessions.md) and [security](../guides/security.md)
guides.

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm`; enforced in
`lib/Vend/Dispatch.pm` and `lib/Vend/Session.pm` via `do_lockout` in
`lib/Vend/Error.pm`.
