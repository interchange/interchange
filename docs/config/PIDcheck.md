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

During each [HouseKeeping](HouseKeeping.md) pass the master checks how long
each child has been busy with a single request. When `PIDcheck` is a
positive interval, any child over it is killed and the active-server count
is decremented. The details depend on how the child was started
(`housekeeping()` in `lib/Vend/Server.pm`):

- **Forked request handlers** — the fork-per-request child in the default
  mode, and the per-connection fork under [PreFork](PreFork.md) when
  [PreForkSingleFork](PreForkSingleFork.md) is off — write a `pid.N` file in
  [RunDir](RunDir.md) for the duration of the request. A file older than
  `PIDcheck` gets `kill -9` outright and a global error log line:

  ```
  hammered PID 21429 running 312 seconds
  ```

  A job runner (see [Jobs](Jobs.md)) uses the same mechanism, with the job's
  `MaxLifetime` as its limit and a `hammered job PID ... for catalog ...`
  message.

- **Pooled page servers** (`PreFork` with `PreForkSingleFork`) report busy
  and idle transitions to the master over IPC instead. A server busy past
  `PIDcheck` is scheduled for termination and logged with the reason:

  ```
  page server pid 21429 busy in one request for 312 seconds (PIDcheck 300); scheduling for termination
  ```

  It is sent `TERM` on that pass; if it is still alive on the next pass it
  is sent `KILL` and the escalation is logged as
  `page server pid 21429 ignored TERM (busy in one request ...); sent KILL`,
  followed by `page server pid 21429 won't die!` if even that fails. The
  same scheduling path (and the same log messages, with their own reasons)
  handles pooled servers that take too long to start or that exceed
  [StartServers](StartServers.md); only the excess-server case is quiet,
  logged at debug level.

Either way the check only fires as often as housekeeping runs, so the
effective granularity is bounded by [HouseKeeping](HouseKeeping.md).

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
[PIDfile](PIDfile.md), [PreFork](PreFork.md),
[PreForkSingleFork](PreForkSingleFork.md), the
[performance](../guides/performance.md) guide.

## Source

Parsed by `parse_time` in `lib/Vend/Config.pm`; consumed via
`$Global::PIDcheck` in `lib/Vend/Server.pm`.
