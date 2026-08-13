# DebugFile

Names the file that Interchange's `::logDebug()` output and (when enabled)
Perl warnings are written to. Reach for it when you need debug tracing
from a running server; it is the destination the debug machinery, the
`debug` search flag, and [DataTrace](DataTrace.md) all write to.

**Scope:** global (`interchange.cfg`)

## Syntax

    DebugFile  filename

A single path (`parse_root_dir`). A relative path is resolved against the
Interchange root directory; an absolute path is used as given. Default:
empty (no debug file, debug output disabled).

## Description

When set, Interchange directs the output of `::logDebug()` statements to
this file. The debug machinery in `lib/Vend/Util.pm` short-circuits
entirely when `$Global::DebugFile` is unset, so leaving this empty
disables debug logging with no runtime cost.

`DebugFile` is also the destination for other debug-oriented features:
[DataTrace](DataTrace.md) DBI tracing writes here, and the search debug
output emitted when a search carries the `debug` flag is gated on
`$Global::DebugFile` being set.

Because `::logDebug()` calls are commented out in the shipped source, you
typically also enable the `DEBUG` variable and uncomment (or script in)
the specific debug statements you want before the file shows useful
content. Setting the file alone does not make Interchange verbose.

## Examples

Send debug output to a file under `/tmp`, with the `DEBUG` variable on:

```
Variable DEBUG 1
DebugFile /tmp/icdebug
```

A path relative to the Interchange root:

```
DebugFile debug.log
```

## Notes

Restrict which requests write debug output with
[DebugHost](DebugHost.md), and control each line's format with
[DebugTemplate](DebugTemplate.md). Changing `DebugFile` takes effect at
server start or reconfiguration.

## See also

[DebugHost](DebugHost.md), [DebugTemplate](DebugTemplate.md),
[DataTrace](DataTrace.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Parsed by `parse_root_dir` in `lib/Vend/Config.pm`; consumed via
`$Global::DebugFile` in `lib/Vend/Util.pm` (the `logDebug` routine),
`lib/Vend/Search.pm`, `lib/Vend/Server.pm`, and `lib/Vend/Table/DBI.pm`.
