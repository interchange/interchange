# ChildLife

Sets a maximum lifetime for a page-server child process, after which it exits
and is replaced. Reach for it in [PreFork](PreFork.md) mode to guarantee that
even idle, never-selected servers are eventually recycled.

**Scope:** global (`interchange.cfg`)

## Syntax

    ChildLife  interval

A time interval such as `30 minutes`, `2 hours`, or `1 day`. A bare number is
taken as seconds. Default: `0` (no lifetime limit; disabled).

## Description

Interchange normally recycles page-server children after they have handled
[MaxRequestsPerChild](MaxRequestsPerChild.md) requests, to guard against
problems in long-running processes such as memory growth. Under
[PreFork](PreFork.md) mode, however, some pre-forked servers may never win the
race to serve a request, so they never reach their request count and are never
retired.

`ChildLife` addresses that by retiring a child once it has been alive for the
given interval, whether or not it has served any requests. When it is unset (or
`0`), starved pre-forked servers are never recycled on their own.

## Examples

Recycle idle pre-forked servers every half hour, in `interchange.cfg`:

```
PreFork Yes
ChildLife 30 minutes
```

## Notes

This directive is only meaningful in [PreFork](PreFork.md) run mode. In the
default (non-prefork) mode, children are recycled by request count and
`ChildLife` is not consulted.

## See also

[PreFork](PreFork.md), [MaxRequestsPerChild](MaxRequestsPerChild.md),
[MaxServers](MaxServers.md), [PIDcheck](PIDcheck.md), the
[performance](../guides/performance.md) guide.

## Source

Parsed by `parse_time` in `lib/Vend/Config.pm` (stored in
`$Global::ChildLife`); consumed by the server child loop in
`lib/Vend/Server.pm`.
