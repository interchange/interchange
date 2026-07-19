# tag

Generic dispatcher for a fixed set of built-in operations, invoked as
`[tag OP ...]BODY[/tag]`. Reach for it to reach operations that have no
dedicated tag of their own, or when you want a single uniform call form.

## Syntax

    [tag OP ARG]BODY[/tag]

Container tag. The operation named by `OP` is dispatched; `BODY` and the
remaining attributes are handed to it. If `OP` is not a recognized operation,
the tag returns `BODY` unchanged.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `op`      |         | The operation to perform (case-insensitive). See the table below. |
| `arg`     |         | The operation's primary argument (meaning depends on `op`). |

Positional order: `op`, `arg` (`PosNumber 2`). Alias: `description` for `arg`.
Additional named attributes (`addAttr`) are passed on to the dispatched
operation.

### Recognized operations

| `op`        | Does |
|-------------|------|
| `pragma`    | Set an ITL pragma (like [flag](flag.md) with a pragma). |
| `flag`      | Set a runtime flag (equivalent to [flag](flag.md)). |
| `log`       | Append to a log file (equivalent to [log](log.md)). |
| `time`      | Format a time (equivalent to [time](time.md); body is the format). |
| `header`    | Emit/replace an HTTP response header. |
| `export`    | Export a database table to its text source. |
| `touch`     | No-op that returns true (used to force evaluation of `addAttr`). |
| `each`      | Iterate every row of a table, interpolating the body per row. |
| `mime`      | Build a MIME part/attachment from the body. |
| `show_tags` | Return the body with ITL tags shown literally (escaped). |

## Description

`[tag]` looks up `op` (uppercased) in an internal operation map and calls the
matching routine, passing the argument, options, and body. Operations that
have their own dedicated tags (`flag`, `log`, `time`, `export`) behave
identically here; `[tag]` exists partly for historical reasons and partly to
reach operations such as `header`, `mime`, `each`, `touch`, and `show_tags`
that are convenient to call generically.

An unrecognized `op` is not an error: the tag simply returns its body
untouched.

## Examples

Send a custom HTTP header (common on pages that must not be cached or indexed):

    [tag op=header]Status: 403 Forbidden to Spiders[/tag]

Format the current time through the `time` operation:

    [tag time]%Y%m%d %H:%M:%S[/tag]

produces, for example:

    20260719 14:05:33

Build a MIME attachment part from the body:

    [tag op=mime description="Order Text" interpolate=1]
    ... order text ...
    [/tag]

## Notes

For everyday use, prefer the dedicated tags ([time](time.md), [flag](flag.md),
[log](log.md), [export](export.md)) — they read more clearly. Keep `[tag]` for
the operations that have no standalone equivalent (`header`, `mime`, `each`,
`show_tags`, `touch`).

## See also

[time](time.md), [flag](flag.md), [log](log.md), [export](export.md),
the [templating](../guides/templating.md) guide.

## Source

Defined in `code/SystemTag/tag.coretag`. Implemented by
`Vend::Interpolate::do_tag` (dispatch map `%Tag_op_map`) in
`lib/Vend/Interpolate.pm`.
