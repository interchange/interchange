# TrackFile

Names the user-tracking log file and, by being set, turns user tracking on.
Reach for it to record page views and selected request data for traffic
reporting, such as affiliate or click-through statistics in the back office.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    TrackFile  path

A file path, relative to the catalog directory unless absolute. The raw string
is stored as-is. Default: empty (no tracking file; user tracking off).

## Description

When `TrackFile` is set, Interchange writes a tracking record for qualifying
requests to the named file. Each line carries a timestamp (formatted by
[TrackDateFormat](TrackDateFormat.md)), the session id, the remote host, the
epoch time, the viewed page, and any request variables selected with
[TrackPageParam](TrackPageParam.md). This data drives traffic summaries in the
administrative interface.

The Interchange server user must be able to create and append to the file.

## Examples

Enable tracking to a log under the catalog (in `catalog.cfg`):

```
TrackFile  logs/usertrack
```

A typical logged line looks like:

```
20050812  fft2VXwJ  127.0.0.1  1123868228  VIEWPAGE=index  var1=TEST var2=500
```

## See also

[TrackDateFormat](TrackDateFormat.md), [TrackPageParam](TrackPageParam.md),
[UserTrack](UserTrack.md), [AsciiTrack](AsciiTrack.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Stored unparsed (no parse routine) in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Track.pm` (and gated in `lib/Vend/Dispatch.pm`) via
`$Vend::Cfg->{TrackFile}`.
