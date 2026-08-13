# HouseKeepingCron

Schedules Interchange-aware periodic work with a crontab-style specification,
replacing the default fixed housekeeping cycle. Reach for it to run catalog jobs
and global routines on precise schedules (hourly, daily, weekdays) from within
Interchange, without an external cron.

**Scope:** global (`interchange.cfg`)

## Syntax

    HouseKeepingCron  <<EOC
    sec min hour day month weekday  target
    ...
    EOC

The value is one or more cron lines, usually supplied as a here-document. Each
line is six time fields followed by a target. Default: empty (Interchange uses
its built-in restart/jobs/reconfig cycle instead).

The six time fields are, in order, **seconds**, **minutes**, **hours**,
**days**, **months**, and **days-of-week**. They accept the usual Vixie-cron
forms -- numbers, ranges, comma lists, `*`, and `*/N` steps -- plus the
extensions provided by `Set::Crontab`: `<N` and `>N` select elements smaller or
larger than `N`, and `!N` excludes `N` from the set.

The **target** is everything after the sixth field: a catalog name plus an
action to run. A catalog name may be prefixed with `>` to run *after* the
reconfig/restart/jobs/pid cycle (the default is before), or with `<`/`=`. Two
special targets, `:reconfig` and `:jobs`, define the intervals at which catalog
reconfiguration and batch job requests are processed.

## Description

`HouseKeepingCron` is Interchange's equivalent of the system cron, evaluated by
the server on each housekeeping wakeup (whose frequency is set by
[HouseKeeping](HouseKeeping.md)). When it is set, Interchange runs the matching
cron entries instead of its default periodic actions.

A target's action is anything Interchange can dispatch through its macro runner
-- a [GlobalSub](GlobalSub.md), a catalog [Sub](Sub.md), or interpolatable
Interchange Tag Language (ITL). There is no catalog request context; everything
executes at the global level.

Because setting `HouseKeepingCron` replaces the default cycle, the `reconfig`
and `jobsqueue` request files in [RunDir](RunDir.md) are ignored unless you
include the `:reconfig` and `:jobs` targets. If you leave them out, Interchange
issues a warning at startup -- omitting them means reconfigure and job requests
are silently dropped, which you almost never want.

## Examples

Process restarts and jobs every five minutes, waking once a minute:

```
HouseKeeping 1 minute

HouseKeepingCron <<EOC
*/5 * * * * * :restart
*/5 * * * * * :jobs
EOC
```

Run named catalog jobs on hourly, daily, weekly, and monthly schedules:

```
HouseKeepingCron <<EOC
0 0 * * * * =standard hourly
0 1 2 * * * =standard daily
0 2 4 * * 7 =standard weekly
0 0 3 1 * * =standard monthly
EOC
```

If a suggested target such as `:reconfig` is missing, the startup warning looks
like:

```
WARNING: suggested cron entry ':reconfig' not present.
```

## Notes

`HouseKeepingCron` requires the `Set::Crontab` Perl module (via `Vend::Cron`).
Remember the leading **seconds** field -- these specs have six time columns, one
more than a standard Unix crontab. Include `:reconfig` and `:jobs` unless you
deliberately want those requests ignored.

## See also

[HouseKeeping](HouseKeeping.md), [RunDir](RunDir.md), [Jobs](Jobs.md),
[GlobalSub](GlobalSub.md), [Sub](Sub.md), the [jobs](../guides/jobs.md) guide.

## Source

Parsed by `parse_cron` in `lib/Vend/Config.pm`; consumed by
`lib/Vend/Cron.pm` (`housekeeping`) and `lib/Vend/Server.pm`, which run the
scheduled targets when `$Global::HouseKeepingCron` is set.
