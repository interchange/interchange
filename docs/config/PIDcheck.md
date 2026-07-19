# PIDcheck

Sets how long a request-handling child may run before the housekeeping
routine kills it. Reach for it to reap hung or runaway server processes on
a busy site.

**Scope:** global (`interchange.cfg`)

## Syntax

    PIDcheck  interval

A time interval. A bare number is seconds; a suffix names other units
(`5 minutes`, `2 hours`). A value of `0` disables the check. Default: `0`.

## Description

During each [HouseKeeping](HouseKeeping.md) pass the server inspects the PID
files of its running children. When `PIDcheck` is a positive interval, any
child that has been busy with a single request for longer than that interval
is sent `kill -9`, and the active-server count is decremented. The server
also writes a line to the global error log, for example:

```
hammered PID 21429 running 312 seconds
```

The check is performed in `lib/Vend/Server.pm` and only fires as often as
housekeeping runs, so the effective granularity is bounded by
[HouseKeeping](HouseKeeping.md).

## Examples

Kill any request that runs longer than five minutes (in `interchange.cfg`):

```
PIDcheck 300
```

Equivalently, using a unit suffix:

```
PIDcheck 5 minutes
```

## Notes

Set this high enough that legitimate long requests are not killed. If the
catalog performs long in-process database builds, either keep `PIDcheck`
disabled, raise it well above the longest expected request (for example
`10 minutes`), or move the heavy work into the `bin/offline` script so it
does not run inside a request child.

## See also

[HouseKeeping](HouseKeeping.md), [MaxRequestsPerChild](MaxRequestsPerChild.md),
[PIDfile](PIDfile.md), the
[performance](../guides/performance.md) guide.

## Source

Parsed by `parse_time` in `lib/Vend/Config.pm`; consumed via
`$Global::PIDcheck` in `lib/Vend/Server.pm`.
