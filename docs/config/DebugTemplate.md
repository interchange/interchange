# DebugTemplate

Defines the format of each line written by `::logDebug()`, letting you
prepend a timestamp and contextual fields (page, tag, host, and more) to
the debug message. Reach for it when raw debug lines are hard to correlate
and you want each stamped with when, where, and for whom it fired.

**Scope:** global (`interchange.cfg`)

## Syntax

    DebugTemplate  format-with-placeholders

A raw string (no parser). The string is first run through
`POSIX::strftime`, so `strftime` specifiers such as `%c`, `%H`, and `%M`
are expanded (use `%%` for a literal `%`). Then brace-delimited
placeholders are substituted. Default: empty (each line is prefixed with
the caller and `:debug:` instead).

## Description

When set, `lib/Vend/Util.pm` builds each debug line from the template
rather than the default `caller():debug: message` form. After the
`strftime` pass, these placeholders are replaced (case-insensitive):

| Placeholder | Value |
|-------------|-------|
| `{MESSAGE}` | the debug message text itself |
| `{PAGE}` | current page (the `MV_PAGE` variable) |
| `{TAG}` | current tag being processed |
| `{HOST}` | remote hostname, or IP if not resolved |
| `{REMOTE_ADDR}` | remote IP address |
| `{REQUEST_METHOD}` | HTTP request method |
| `{REQUEST_URI}` | request URI |
| `{CATALOG}` | catalog name |
| `{PID}` | process ID |
| `{CALLER0}` ... `{CALLER9}` | elements of Perl's `caller()` list |
| `{SESSION.key}` | the named key from the current session |

Fields with no value expand to empty. The assembled line is written to
[DebugFile](DebugFile.md) (or to the system log when `SysLog` is
configured).

## Examples

Prefix each debug line with a timestamp, the immediate caller, the
message, and the page and tag it came from:

```
DebugTemplate %c {CALLER0} {MESSAGE} {PAGE} {TAG}
```

A line from that template looks like:

    Sun Jul 19 14:22:05 2026 Vend::Interpolate your message here flypage item-price

## Notes

The template applies only when [DebugFile](DebugFile.md) is set and
`::logDebug()` actually runs. The historic manual listed only a subset of
placeholders; the fields above are those the current code substitutes.

## See also

[DebugFile](DebugFile.md), [DebugHost](DebugHost.md),
[DataTrace](DataTrace.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Stored unparsed in `lib/Vend/Config.pm`; consumed via
`$Global::DebugTemplate` in the `logDebug` routine of `lib/Vend/Util.pm`.
