# usertrack

Record a custom name/value data point into Interchange's user-tracking log for
the current session. Reach for it to log application-specific events (a promo
click, a step reached) alongside the built-in traffic tracking.

## Syntax

    [usertrack tag value]
    [usertrack tag="event" value="signup_started"]

Standalone tag (no end tag). Returns nothing.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `tag`     |         | Label for the data point (positional 1). |
| `value`   |         | Value to record under that label (positional 2). |

Positional order: `tag`, `value`.

## Description

The tag appends the `tag`/`value` pair to the session's tracking action list
(`$Vend::Track->user(...)`). When tracking is active, that list is flushed to
the configured tracking log at the end of the request. If the tracking object
is not present, the tag is a no-op.

User tracking is governed by the catalog's tracking configuration: the
`UserTrack` directive turns per-session tracking on, and `TrackFile` names the
log the accumulated actions are written to. Without tracking enabled, calls to
`[usertrack]` are harmless but have no persistent effect.

## Examples

Log a named event:

    [usertrack event checkout_started]

Record a value pulled from a form field:

    [usertrack tag="referrer" value="[value referral_code]"]

## Notes

- This only queues the data point on the in-memory tracking object; whether it
  is persisted depends on the `UserTrack`/`TrackFile` configuration for the
  catalog.
- The strap demo ships with `UserTrack no` and `TrackFile` commented out;
  enable both to capture tracked data.

## See also

- The [logging and debugging guide](../guides/logging-debugging.md)
- The [sessions guide](../guides/sessions.md)

## Source

Defined in `code/UserTag/usertrack.tag` (inline `Routine`); records via
`Vend::Track::user`.
