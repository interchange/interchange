# LogTimeFormat

Sets the timestamp format used when Interchange writes entries to its logs.
Reach for it when you want log timestamps to match a particular convention,
for example to feed a log analyzer.

**Scope:** global (`interchange.cfg`)

## Syntax

    LogTimeFormat  strftime-format

A `POSIX::strftime` format string, stored verbatim (no parser is run).
Default: `[%d/%B/%Y:%H:%M:%S %z]`.

## Description

The value is passed straight to `POSIX::strftime` by the `logtime` routine in
`lib/Vend/Util.pm`:

```perl
sub logtime {
    return POSIX::strftime($Global::LogTimeFormat, localtime());
}
```

`logtime` supplies the timestamp that `format_log_msg` prepends to error-log
lines, so the format you set here determines how the leading timestamp of each
logged message looks. The default renders like the Common Log Format date
field, for example:

```
[19/July/2026:14:22:03 -0500]
```

Any `strftime` conversion is accepted; the surrounding literal text (such as
the square brackets in the default) is kept as-is. The directive is read at
startup and applies globally.

## Examples

Use an ISO-8601-style timestamp:

```
LogTimeFormat %Y-%m-%d %H:%M:%S
```

Restore the default Common Log Format bracketed date:

```
LogTimeFormat [%d/%B/%Y:%H:%M:%S %z]
```

## See also

[Logging](Logging.md), [DebugFile](DebugFile.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Stored unparsed (no `parse_*` routine) in `lib/Vend/Config.pm`; consumed via
`$Global::LogTimeFormat` in `logtime` in `lib/Vend/Util.pm`.
