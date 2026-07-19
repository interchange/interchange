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
The distributed `interchange.cfg` uses `MaxServers 0` in its traffic-tuning
profiles, leaving process count unbounded and relying on other limits.

This is a global startup setting.

## Examples

Allow at most 20 concurrent page servers:

```
MaxServers 20
```

Remove the limit (as the shipped traffic profiles do):

```
MaxServers 0
```

## See also

[MaxRequestsPerChild](MaxRequestsPerChild.md), [StartServers](StartServers.md),
[PreFork](PreFork.md), [PIDcheck](PIDcheck.md), [HouseKeeping](HouseKeeping.md),
the [performance](../guides/performance.md) guide.

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm`; consumed via
`$Global::MaxServers` in `lib/Vend/Server.pm`.
