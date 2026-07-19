# HitCount

Bumps a per-catalog counter file on every top-level access to the catalog.
Reach for it as a crude built-in traffic tally when you do not want to parse web
server logs.

**Scope:** global (`interchange.cfg`)

## Syntax

    HitCount  yes|no

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`). Default: `No`.

## Description

With `HitCount` enabled, each time Interchange serves a catalog's top-level
request it increments a counter file named `hits.CATALOGNAME` in the catalog's
configuration directory (`ConfDir`, normally `etc/`). The count accumulates
across restarts because it lives in a file.

The counter is bumped only for the base catalog access, not for every internal
sub-request, so it approximates page views rather than counting each asset.
Although the directive is global, the counter file it maintains is per catalog.

## Examples

Enable hit counting for all catalogs (`interchange.cfg`):

```
HitCount Yes
```

After some traffic, `etc/hits.mystore` holds the running total for the
`mystore` catalog.

## Notes

`HitCount` is a coarse measure and adds a file update to each request; leave it
off unless you specifically want the tally. For richer per-request logging see
[TrackFile](TrackFile.md) and the logging facilities.

## See also

[TrackFile](TrackFile.md), [ConfDir](ConfDir.md), [Logging](Logging.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Dispatch.pm`, which increments a `Vend::CounterFile` named
`hits.$Vend::Cat` under `$Global::ConfDir` when `$Global::HitCount` is set.
