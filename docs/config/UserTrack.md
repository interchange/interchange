# UserTrack

Controls whether Interchange emits the `X-Track` HTTP response header, which
carries page-tracking data for the session. Reach for it to turn the
tracking header on or off independently of file-based tracking.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    UserTrack  yes|no

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default: `no`.

## Description

When `UserTrack` is enabled, Interchange creates a `Vend::Track` object for
the request and, at response time, appends the tracking data as an `X-Track`
header:

```perl
$Vend::StatusLine .= "X-Track: " . $Vend::Track->header() . "\r\n"
```

Tracking is also activated when [TrackFile](TrackFile.md) is set, so either
directive turns the machinery on. `UserTrack` is the switch for the HTTP
header specifically. Tracking is suppressed for admin requests unless the
`MV_TRACK_ADMIN` [Variable](Variable.md) is set.

## Examples

Disable the `X-Track` header (in `catalog.cfg`):

```
UserTrack no
```

Enable it:

```
UserTrack yes
```

## Notes

Prior to Interchange 5.5.2 there was no way to control the `X-Track`
header: it was emitted unconditionally whenever [TrackFile](TrackFile.md)
was defined. `UserTrack` was added to make the header optional.

## See also

[TrackFile](TrackFile.md), [AsciiTrack](AsciiTrack.md),
[usertrack](../tags/usertrack.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Dispatch.pm` (creating the tracker) and `lib/Vend/Server.pm`
(emitting the `X-Track` header).
