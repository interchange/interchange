# TrackDateFormat

Sets the timestamp format used in the user-tracking log written by
[TrackFile](TrackFile.md). Reach for it to match the log's date column to
another system, such as an Apache-style or ISO 8601 timestamp.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    TrackDateFormat  strftime-format

A `POSIX::strftime` format string (for example `%Y%m%d` or
`%d/%b/%Y:%H:%M:%S %z`). The raw string is stored as-is. Default: empty in the
directive table, but the tracking code falls back to `%Y%m%d` when the directive
is unset, so the effective default is `%Y%m%d`.

## Description

Each entry Interchange writes to the [TrackFile](TrackFile.md) log begins with a
timestamp. `TrackDateFormat` is passed to `POSIX::strftime` to format that
timestamp. It has no effect unless [TrackFile](TrackFile.md) (or
[UserTrack](UserTrack.md)) is enabled.

## Examples

Use an Apache-style timestamp (in `catalog.cfg`):

```
TrackFile        logs/usertrack
TrackDateFormat  %d/%b/%Y:%H:%M:%S %z
```

Use an ISO 8601 timestamp:

```
TrackDateFormat  %Y-%m-%dT%H:%M:%S%z
```

## See also

[TrackFile](TrackFile.md), [TrackPageParam](TrackPageParam.md),
[UserTrack](UserTrack.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Stored unparsed (no parse routine) in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Track.pm` via `$Vend::Cfg->{TrackDateFormat}` (with a `%Y%m%d`
fallback).
