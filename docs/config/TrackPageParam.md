# TrackPageParam

Selects, per page, which CGI variables' values are written into the
[TrackFile](TrackFile.md) user-tracking log. Reach for it to capture specific
request parameters (a campaign id, a search term) alongside the page view.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    TrackPageParam  page  var1,var2  page2  var3,var4 ...

A whitespace-separated set of `page var-list` pairs parsed as a hash. The key is
a page name (without the `.html` suffix); the value is a comma-separated list of
CGI variable names to record for that page. Pairs accumulate. Default: empty
(only the page view itself is logged).

## Description

When a tracked page is viewed, Interchange looks up its name in
`TrackPageParam`; for each listed variable that was passed to that page as a CGI
variable, it appends `NAME=value` to the tracking record. A variable is logged
only if it is both named here and actually present in the request. The directive
has no effect unless [TrackFile](TrackFile.md) is set.

## Examples

Record two variables on `index` and two others on `index2`
(in `catalog.cfg`):

```
TrackFile       logs/trackfile
TrackPageParam  index var1,var2  index2 var3,var4
```

Visiting `index.html?var1=TEST&var2=500` then produces a log line such as:

```
20050812  fft2VXwJ  127.0.0.1  1123868228  VIEWPAGE=index  var1=TEST var2=500
```

## See also

[TrackFile](TrackFile.md), [TrackDateFormat](TrackDateFormat.md),
[UserTrack](UserTrack.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Track.pm` via `$Vend::Cfg->{TrackPageParam}`.
