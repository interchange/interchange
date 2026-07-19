# LogFile

Names the catalog's general-purpose log file -- the default destination for
the [log](../tags/log.md) tag and other logged data. Reach for it to change
where catalog log output is written.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    LogFile  PATH

A path, stored verbatim (no parser). A relative path is taken relative to
the catalog root directory. Default: `etc/log`.

## Description

`LogFile` sets the default file that receives output from Interchange's
internal `logData()` function -- most visibly the [log](../tags/log.md)
tag, but also assorted catalog logging such as UserDB events. This is the
catalog's own activity log, distinct from the error log
([ErrorFile](ErrorFile.md)) and the debug log.

The value is only the *default*; callers can direct output elsewhere. The
[log](../tags/log.md) tag accepts a `file` attribute, and internal callers
pass their own filename, either of which overrides `LogFile` for that
write.

The directive is read at catalog configuration time.

## Examples

Send catalog log output to `etc/catlog` (put in `catalog.cfg`):

```
LogFile etc/catlog
```

Then, from a page, append a line to that default log:

```
[log]Order placed for [value mv_order_number][/log]
```

## Notes

Because the path is relative to the catalog root, `etc/log` resolves under
the catalog directory, not the Interchange root. Give an absolute path to
log outside the catalog tree.

## See also

[ErrorFile](ErrorFile.md), [log](../tags/log.md),
[AsciiTrack](AsciiTrack.md), the
[logging and debugging](../guides/logging-debugging.md) guide.

## Source

Stored raw (no parser) from the `catalog_directives()` table in
`lib/Vend/Config.pm`; used as the default log destination in
`Vend::Interpolate` (the `log` tag) and `lib/Vend/UserDB.pm`, both via
`Vend::Util::logData`.
