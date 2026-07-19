# log

Append a message from the tag body to a log file. Reach for it to record
custom, possibly multi-line, entries to the catalog error log or to a log
file of your own.

## Syntax

    [log]message[/log]
    [log file=var/log/custom.log]message[/log]
    [log type=error]message[/log]

Container tag. The body is **not** interpolated by default; add
`interpolate=1` to interpolate it first.

## Attributes

| Attribute      | Default | Description |
|----------------|---------|-------------|
| `file`         | [LogFile](../config/LogFile.md) | Path of the log file to append to. A leading `>` forces `create`. |
| `create`       | off     | Create (truncate) the file rather than append. Set automatically when `file` begins with `>`. |
| `type`         | (plain) | `text`, `quot`, `error`, or `debug` — see below. |
| `process`      | strip   | Message pre-processing; `nostrip` disables the default whitespace/newline normalization. |
| `delimiter`    | tab     | Field delimiter for the default (field-logging) mode. |
| `record_delim` | newline | Record delimiter splitting the body into multiple log lines. |
| `hide`         | off     | Return empty string instead of the write status. |

Positional order: `file`.
Alias: `arg` for `file`.

## Description

`[log]` writes the message text to a log file, appending by default. With no
`file`, it uses the catalog [LogFile](../config/LogFile.md) (normally
`error.log`). The target path is checked against Interchange's file-access
rules; a disallowed path is refused and logged as a violation.

By default the body has leading and trailing whitespace stripped and CRLF
sequences normalized to `\n`. Pass `process=nostrip` to log the body
verbatim.

The `type` attribute selects the format:

- **(none)** — the body is split into records by `record_delim` and each
  record into fields by `delimiter`, then written as delimited log data.
- **`text`** — the body is written as-is to `file`.
- **`quot`** — each record's fields are shell-quoted before writing.
- **`error`** — the message is formatted like a standard Interchange error
  line; with a `file` it is written there, otherwise it goes to the catalog
  error log via `logError`.
- **`debug`** — like `error` but routed through `logDebug`.

## Examples

Log an error-formatted message to the catalog error log:

    [log type=error]
    An error occurred.
    [/log]

Interpolate the body first so it can include live values:

    [log type=error interpolate=1]
    Checkout failed for [value email].
    [/log]

Append a line to your own log file:

    [log file=var/log/custom.log]
    Custom log message.
    [/log]

## Notes

The field delimiter is keyed internally as `delimiter` in the writing loop
but is not passed through the same escape-evaluation step that
`record_delim` receives, so a `delimiter` given as a backslash escape (for
example `\t`) is taken literally rather than converted to a tab. Use the
default tab delimiter, or supply a literal delimiter character, if this
matters. (This is a known quirk of the current implementation.)

## See also

- [LogFile](../config/LogFile.md) — the default log target
- [debug](debug.md) — write to the debug log
- [error](error.md), [warnings](warnings.md)
- [logging and debugging](../guides/logging-debugging.md)

## Source

Defined in `code/SystemTag/log.coretag`. Implemented by
`Vend::Interpolate::log` (`lib/Vend/Interpolate.pm`).
