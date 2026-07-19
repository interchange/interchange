# SysLog

Routes Interchange's global log output to the Unix system logger (syslog)
instead of a flat file, and tunes the facility, tag, and per-level mapping used
to do so.

**Scope:** global (`interchange.cfg`)

## Syntax

    SysLog  KEY  VALUE

The value is a set of `key value` pairs (parser type `hash`); each line sets one
key. Default: unset (Interchange logs to [ErrorFile](ErrorFile.md)). Recognized
keys:

- `facility` -- the syslog facility to log under (default `local3`).
- `tag` -- the syslog tag/ident prefixed to each message (default
  `interchange`; the literal `none` suppresses the tag with the external
  `logger` command).
- `command` -- the external program used to submit messages (default `logger`).
- `internal` -- when true, log through Perl's `Sys::Syslog` directly rather
  than piping to an external `command`.
- `socket` -- the syslog socket specification passed to `Sys::Syslog`
  (`internal` mode) or as the `logger -u` socket.
- level keys (`alert`, `warn`, `info`, `debug`, `err`, `emerg`, ...) -- remap a
  message level to a `facility.priority` (or a bare priority). For example
  `warn local3.info` sends warning-level messages at `local3.info`.

## Description

When `SysLog` is set, Interchange stops writing global errors to the flat log
file and instead submits each message to syslog. By default it pipes messages
to the `logger(1)` command as `logger -t TAG -p FACILITY.PRIORITY ...`; setting
`internal 1` uses the `Sys::Syslog` Perl module instead. The level keys let you
map Interchange's message levels onto whatever facility/priority combinations
your syslog configuration expects. Because a `command` is invoked, you can also
point it at a custom wrapper script to route messages anywhere (a database, for
instance).

Where syslog ultimately writes the messages is controlled by the system's
syslog daemon configuration (typically `/etc/syslog.conf` or the rsyslog
equivalent), not by Interchange.

## Examples

Log through `logger` with tag `int1`, sending each level to a `local3`
priority:

```
SysLog  command  /usr/bin/logger
SysLog  tag      int1
SysLog  alert    local3.warn
SysLog  warn     local3.info
SysLog  info     local3.info
SysLog  debug    local3.debug
```

This produces messages such as:

```
Oct 26 17:30:13 bill int1: START server (2345) (INET and UNIX)
```

Route `local3` messages to a dedicated file, in the system's `syslog.conf`:

```
# Log local3 stuff to Interchange log
local3.*                /var/log/interchange.log
```

## See also

[ErrorFile](ErrorFile.md), [DebugFile](DebugFile.md), [Logging](Logging.md),
the [logging-debugging](../guides/logging-debugging.md) guide.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm` (stored in `$Global::SysLog`);
consumed by the logging routine in `lib/Vend/Util.pm`.
