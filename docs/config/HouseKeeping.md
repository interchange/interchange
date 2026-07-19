# HouseKeeping

Sets how often, in seconds, the Interchange server wakes up to do periodic
maintenance -- checking for reconfigure requests, hung processes, and scheduled
work. It is the server's heartbeat interval.

**Scope:** global (`interchange.cfg`)

## Syntax

    HouseKeeping  INTERVAL

A time interval -- a bare number of seconds, or a phrase such as `2 minutes` or
`1 hour`, converted to seconds. Default: `60`.

## Description

The main Interchange server process sleeps between requests and wakes at most
every `HouseKeeping` seconds to perform its housekeeping pass: looking for
catalog reconfiguration requests, reaping or checking hung child processes, and
(unless [HouseKeepingCron](HouseKeepingCron.md) overrides the schedule) running
the periodic restart/jobs cycle. On some systems this wakeup is also the point
at which the server notices and acts on a `-stop` command.

A shorter interval makes the server more responsive to reconfigure and stop
requests at the cost of waking more often; a longer interval is calmer but adds
latency to those actions. If the value is unset or zero, the server falls back
to a 60-second tick.

## Examples

Wake every two minutes (`interchange.cfg`):

```
HouseKeeping 2 minutes
```

Wake every hour:

```
HouseKeeping 1 hour
```

The distribution `interchange.cfg` tunes it by traffic profile, for example:

```
HouseKeeping 3
```

## Notes

When [HouseKeepingCron](HouseKeepingCron.md) is configured, the *what* of the
periodic cycle is driven by cron entries rather than the default
restart/jobs/reconfig set, but `HouseKeeping` still sets how frequently the
server wakes to evaluate them.

## See also

[HouseKeepingCron](HouseKeepingCron.md), [PIDcheck](PIDcheck.md),
[MaxServers](MaxServers.md), [Jobs](Jobs.md), the
[jobs](../guides/jobs.md) guide.

## Source

Parsed by `parse_time` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm`, where `$Global::HouseKeeping` (defaulting to 60) sets the
server select-loop tick that triggers each housekeeping pass.
