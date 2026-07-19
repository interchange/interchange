# MaxRequestsPerChild

Sets how many requests a single Interchange server process handles before it
exits and is respawned. Reach for it to bound the memory growth of long-lived
server processes.

**Scope:** global (`interchange.cfg`)

## Syntax

    MaxRequestsPerChild  count

An integer (`parse_integer`). `0` disables the limit (processes are not
recycled on a request count). Default: `50`.

## Description

Each Interchange server process keeps a running count of the requests it has
handled. When that count reaches `MaxRequestsPerChild`, the process finishes
the current request and then exits so a fresh one can take its place. The
check is in `lib/Vend/Server.pm`:

```perl
return 1   if  $Global::MaxRequestsPerChild
               and $handled >= $Global::MaxRequestsPerChild;
```

Periodic recycling limits the effect of any slow memory growth (leaks) in a
process, since the memory is reclaimed when the process exits. A lower value
recycles more aggressively at the cost of more process startups; a higher
value keeps processes alive longer. This is a global startup setting; it
applies to every page-serving process.

## Examples

Recycle each server process after 100 requests, as used by the "rpc" traffic
profile in the distributed `interchange.cfg`:

```
MaxRequestsPerChild 100
```

## See also

[MaxServers](MaxServers.md), [StartServers](StartServers.md),
[PreFork](PreFork.md), [PIDcheck](PIDcheck.md), [HouseKeeping](HouseKeeping.md),
the [performance](../guides/performance.md) guide.

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm`; consumed via
`$Global::MaxRequestsPerChild` in `lib/Vend/Server.pm`.
