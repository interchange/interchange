# timed-display

Show the body only within a start/stop date-time window; otherwise show an
optional `[else]` block. Reach for it to schedule promotional copy, banners, or
notices that should appear only during a set period.

## Syntax

    [timed-display start=2026072008 stop=2026072012]
    shown only inside the window
    [else]shown outside the window[/else]
    [/timed-display]

Container tag. Both bounds are optional.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `start`   | now     | Beginning of the display window (positional 1). Omit for "from now / already started". |
| `stop`    | far future | End of the display window (positional 2). Omit for "no end". |
| `tv`      |         | Name of a CGI or scratch variable holding a date string to use as "now" (for testing). |
| `adjust`  |         | Passed to [convert-date](convert-date.md); shifts the comparison time (e.g. timezone offset). |

Positional order: `start`, `stop`.

## Description

The tag compares the current time against `start` and `stop`. If now falls
within `[start, stop]`, it returns the main body; otherwise it returns the
`[else]` block (empty if none). With only `start`, the block displays from that
time onward; with only `stop`, it displays until that time.

`start`, `stop`, and the current time are all normalized through
[convert-date](convert-date.md) to `%Y%m%d%H%M`, so you may give the bounds in
any format that tag accepts. `adjust` is forwarded to those conversions to
shift the effective time — useful for aligning to a timezone other than the
server's.

For testing outside wall-clock time, set `tv` to the name of a CGI or scratch
variable; when present, its date string is converted and used as "now" instead
of the real clock.

## Examples

Show a sale banner only during a set window:

    [timed-display start="2026-07-20 08:00" stop="2026-07-20 12:00"]
    <div class="sale">Flash sale — 20% off until noon!</div>
    [/timed-display]

Open-ended (from a launch date onward), with a fallback before launch:

    [timed-display start="2026-08-01"]
    Now available!
    [else]Coming August 1.[/else]
    [/timed-display]

## Notes

- The tag's embedded documentation calls the test-time option `timevar`, but
  the code reads the attribute `tv` — use `tv`.
- Because bounds pass through [convert-date](convert-date.md), an unparseable
  `start`/`stop` becomes a false value and the tag falls back to its default
  bound rather than erroring.

## See also

- [convert-date](convert-date.md) — the date parsing/formatting used here
- [time](time.md) — format the current time
- The [templating guide](../guides/templating.md)

## Source

Defined in `code/UserTag/timed_display.tag` (inline `Routine`), registered as
`timed-display`.
