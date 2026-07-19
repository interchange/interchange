# Logging

Sets a verbosity threshold for extra request logging. Reach for it when you
need Interchange to record incoming HTTP request headers, and optionally
POST form data, in the global log.

**Scope:** global (`interchange.cfg`)

## Syntax

    Logging  integer

An integer threshold (`parse_integer`). Default: `0`.

## Description

Despite the general-sounding name, this directive currently controls only two
things, both handled by `log_http_data` in `lib/Vend/Server.pm`:

| Value    | Effect |
|----------|--------|
| `0`–`4`  | no extra logging (the request-header/POST logging is skipped) |
| `> 4`    | logs selected HTTP request headers as an `access:` line |
| `> 5`    | additionally logs the raw POST body of form submissions |

The header logging is triggered per request wherever Interchange calls
`log_http_data`, which runs only `if $Global::Logging` is set at all, then the
routine itself returns immediately unless the value is greater than `4`. The
set of headers recorded defaults to `REQUEST_URI`, `HTTP_COOKIE`,
`SERVER_NAME`, `REMOTE_ADDR`, `HTTP_HOST`, `HTTP_USER_AGENT`, and
`REMOTE_USER`, and can be overridden through the `http_items` key of
[SysLog](SysLog.md). Messages are written with [logGlobal](../tags/log.md) at
`info` level (headers) and `debug` level (POST body).

`Logging` is read at startup and is not per-catalog.

## Examples

Log request headers and POST data for every request:

```
Logging 6
```

Turn the extra logging off (the default):

```
Logging 0
```

## Notes

Level `> 5` writes complete POST bodies to the log, which will include any
data a customer submits -- passwords, card numbers, personal details. Enable
it only briefly, for debugging, and protect the log file.

Aside from these two thresholds the directive has no other effect in the
current code; it is not a general log-level control.

## See also

[SysLog](SysLog.md), [DebugFile](DebugFile.md), [DataTrace](DataTrace.md),
[ShowTimes](ShowTimes.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm`; consumed via
`$Global::Logging` in `log_http_data` in `lib/Vend/Server.pm` (also
`lib/Vend/ModPerl.pm`).
