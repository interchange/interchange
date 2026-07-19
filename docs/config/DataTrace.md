# DataTrace

Sets the DBI trace level for Interchange's SQL database calls, sending the
trace to the debug file. Reach for it only when diagnosing a problem you
believe involves DBI, since it produces a large volume of output.

**Scope:** global (`interchange.cfg`)

## Syntax

    DataTrace  level

An integer (`parse_integer`). `0` disables tracing; higher numbers are
progressively more verbose DBI trace levels. Default: `0`.

## Description

When non-zero, Interchange calls DBI's `trace` method with this level on
each database handle, writing the trace to [DebugFile](DebugFile.md):

```perl
$db->trace($Global::DataTrace, $Global::DebugFile)
    if $Global::DataTrace and $Global::DebugFile;
```

Tracing therefore only happens when [DebugFile](DebugFile.md) is also set.
The levels follow DBI's own scheme:

| Level | Output |
|-------|--------|
| `0`   | tracing off |
| `1`   | DBI method calls with their return values or errors |
| `2`   | level 1 plus the parameters passed to each call |
| `3`   | level 2 plus high-level driver and internal DBI detail |
| `4`   | level 3 plus more detailed driver information |
| `5`+  | increasingly obscure internal detail |

Level `1` is enough for most investigations.

## Examples

Enable basic DBI tracing to a debug file:

```
DebugFile /tmp/icdebug
DataTrace 1
```

## Notes

`DataTrace` has no effect without [DebugFile](DebugFile.md) set, because
the trace is written there. The output can grow quickly on a busy server;
turn it back to `0` when you are done.

## See also

[DebugFile](DebugFile.md), [DebugHost](DebugHost.md),
[DebugTemplate](DebugTemplate.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm`; consumed via
`$Global::DataTrace` in `lib/Vend/Table/DBI.pm`.
