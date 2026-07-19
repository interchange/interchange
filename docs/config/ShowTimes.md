# ShowTimes

Adds process timing marks to the debug log at key points in request handling.
Reach for it when profiling where request time is spent and you already have
debug logging turned on.

**Scope:** global (`interchange.cfg`)

## Syntax

    ShowTimes  yes|no

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default: `No`.

## Description

When enabled, Interchange calls its `show_times()` routine at instrumented
points -- for example after reading the CGI request, at the start of dispatch,
and around the table editor -- writing the accumulated user and system CPU times
(from Perl's `times()`) to the debug log as time marks relative to the start of
the request.

Because the output goes through `logDebug`, debug logging must be active for the
marks to appear (see the `DEBUG` variable and
[DebugFile](DebugFile.md)). The directive is read at startup.

## Examples

Enable timing marks. In `interchange.cfg`:

```
ShowTimes  Yes
```

## Notes

Many `show_times()` calls in the source are commented out; only a subset (in the
server dispatch loop, the mod_perl handler, and the table editor) are active. To
instrument additional points you must uncomment the corresponding
`show_times(...) if $Global::ShowTimes;` lines in the source and restart. You
can find them with `grep -r ShowTimes` in the Interchange root.

## See also

[DebugFile](DebugFile.md), [DataTrace](DataTrace.md),
[Logging](Logging.md), the [logging and debugging](../guides/logging-debugging.md)
and [performance](../guides/performance.md) guides.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm` (`global_directives()`).
Consumed via `$Global::ShowTimes` in `lib/Vend/Server.pm`,
`lib/Vend/ModPerl.pm`, and `lib/Vend/Table/Editor.pm`; the timing routine is
`show_times` in `lib/Vend/Util.pm`.
