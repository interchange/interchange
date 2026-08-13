# time

Format a date/time using a `strftime`-style format string. Reach for it to
print the current date, a stored epoch time, or a time offset from now, in any
layout or locale.

## Syntax

    [time]FORMAT[/time]
    [time locale=LOCALE tz=... time=... adjust=...]FORMAT[/time]

Container tag. The body is the `strftime(3)` format string. With an empty body
the default format `%c` is used.

## Attributes

| Attribute        | Default | Description |
|------------------|---------|-------------|
| `locale`         |         | Format according to the named system `LC_TIME` locale (month/day names, etc.); the locale must be installed on the host. |
| `tz`             |         | Time zone for this call, in `TZ` form (e.g. `PST8PDT`, `GMT0`). |
| `time`           | now     | Epoch seconds to format instead of the current time. |
| `sortable`       | `0`     | Shortcut that forces the format to `%Y%m%d`. |
| `adjust`         |         | Offset applied to the time before formatting (hours, timezone-style, or an interval like `2 days`). |
| `hours`          |         | Force `adjust` to always be interpreted as hours. |
| `format` / `fmt` | `%c`    | Format string, used when the body is empty. |
| `gmt`            | `0`     | Format in GMT/UTC rather than local time. |
| `zerofix`        | `0`     | Strip leading zeros from numbers in the result. |
| `compensate_dst` |         | Compensate for a daylight-saving shift when adjusting. |

Positional order: `locale` (`PosNumber 1`).

## Description

The tag returns the given time (default: Perl `time()`) formatted with
`POSIX::strftime`. The format comes from the body, or from `fmt`/`format`, or
defaults to `%c`. Set `gmt` to format in UTC.

`adjust` shifts the moment before formatting. A plain number is treated as
hours; a three-or-more-digit value ending in `0` is treated as a timezone-style
offset (minutes-in-the-last-two-digits), and a string such as `2 days` or
`5 weeks` is treated as an interval. Because the shift is applied to the epoch
value only, do not combine `adjust` with a format that prints the zone name —
use `tz` if the zone must be correct.

`locale` and `tz` are set only for the duration of the call and restored
afterward.

## Examples

Print the current year (used in copyright lines):

    [time]%Y[/time]

produces:

    2026

An ISO 8601 timestamp suitable for a SQL `datetime` column:

    [time]%Y-%m-%d %H:%M:%S[/time]

Convert a stored epoch value to a readable date:

    [time time="1261306319"]%Y-%m-%d %H:%M:%S[/time]

produces:

    2009-12-20 11:31:59

A date five weeks from now:

    [time adjust="5 weeks"]%b %e, %Y[/time]

Localized month names:

    [time locale=fr_FR]%B %d, %Y[/time]

## Notes

- `strftime` format specifiers are those of the host C library; availability of
  a given `locale` also depends on the host.
- The whole installation's default zone can be set by exporting `TZ` before
  starting Interchange.

## See also

[convert-date](convert-date.md), [tag](tag.md) (the `time` operation),
[setlocale](setlocale.md),
the [internationalization](../guides/internationalization.md) guide.

## Source

Defined in `code/SystemTag/time.coretag`. Implemented by
`Vend::Interpolate::mvtime` in `lib/Vend/Interpolate.pm`.
