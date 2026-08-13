# debug

Writes its body to the Interchange debug log. Reach for it to trace values
on a page while developing, without printing anything to the shopper.

## Syntax

    [debug]message text[/debug]

Container tag (has an end tag). The body is interpolated first, then
logged; the tag itself produces no page output.

## Attributes

None.

## Description

The tag maps to `Vend::Util::logDebug`. The interpolated body is written to
the debug log — but only when debugging is enabled: `logDebug` returns
immediately unless the global `DebugFile` directive is set. When the
`DebugHost` directive is configured, the message is further limited to
requests from matching client addresses, and a `DebugTemplate` controls the
log-line format (timestamp, page, tag, PID, and similar fields).

Because the body is interpolated, you can log the current value of any tag
or variable. The message never reaches the browser, so it is safe to leave
`[debug]` calls in a page during development.

## Examples

Log the cart size and session id:

    [debug]There are [nitems] items in session [data session id][/debug]

Trace a scratch value at a point in the page:

    [debug]checkout stage = [scratch checkout_stage][/debug]

## Notes

Nothing is logged unless `DebugFile` is set for the server; on a
production catalog with debugging off, `[debug]` is effectively a no-op.
See the [logging-debugging](../guides/logging-debugging.md) guide for how
to enable and read the debug log.

## See also

[comment](comment.md), [log](log.md), [dump](dump.md),
[DebugFile](../config/DebugFile.md), [DebugHost](../config/DebugHost.md),
[DebugTemplate](../config/DebugTemplate.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Defined in `code/SystemTag/debug.coretag`. Implemented by
`Vend::Util::logDebug` in `lib/Vend/Util.pm`.
