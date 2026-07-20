# MaxServers

Caps the number of Interchange page-serving processes that run at once. Reach
for it to keep a busy site from spawning more server processes than the
machine can support.

**Scope:** global (`interchange.cfg`)

## Syntax

    MaxServers  count

An integer (`parse_integer`). `0` disables the cap, so no per-process limit is
enforced. Default: `10`.

## Description

Interchange forks a separate process to handle each incoming request. When the
number of running servers exceeds `MaxServers`, the master process stops
accepting new HTTP connections during housekeeping (it listens only on the
internal IPC socket) until the count drops, so additional requests queue at the
operating-system level -- typically the listen backlog -- until a slot frees.
The comparison is in `lib/Vend/Server.pm`:

```perl
if ($Global::MaxServers and $Num_servers > $Global::MaxServers) {
    $only_ipc = $ipc;
}
```

A value of `0` is special: the running-server accounting (the `USR1`/`USR2`
increment/decrement signals) is turned off entirely and no limit is applied.

> **Recommendation: leave this at `0`.** The running-server count is
> maintained by Perl signal handlers (`USR1`/`USR2`), and Perl signal
> delivery is not reliable enough for this accounting — the count drifts,
> and with it the enforcement. This is why every traffic profile in the
> shipped `interchange.cfg` sets `MaxServers 0` despite the directive
> table's nominal default of `10`. In [PreFork](PreFork.md) mode,
> compensate by sizing [StartServers](StartServers.md) to the actual
> number of pre-forked daemons you want — that pool size, not
> `MaxServers`, is the concurrency knob. In fork-per-request mode, shape
> concurrency at the web server or load balancer.

This is a global startup setting.

## Examples

The shipped configuration, and the recommended setting:

```
MaxServers 0
```

In PreFork mode, size the pool with `StartServers` instead of capping
with `MaxServers`:

```
PreFork      Yes
StartServers 8
MaxServers   0
```

## See also

[MaxRequestsPerChild](MaxRequestsPerChild.md), [StartServers](StartServers.md),
[PreFork](PreFork.md), [PIDcheck](PIDcheck.md), [HouseKeeping](HouseKeeping.md),
the [performance](../guides/performance.md) guide.

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm`; consumed via
`$Global::MaxServers` in `lib/Vend/Server.pm`.
