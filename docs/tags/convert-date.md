# convert-date

Format a date with POSIX `strftime`, optionally shifting it by a number of
days first. The date to format is the tag body; with no body it uses the
current time. Reach for it to display order dates, timestamps, or a formatted
"today".

## Syntax

    [convert-date]DATE[/convert-date]
    [convert-date ADJUST]DATE[/convert-date]
    [convert-date fmt="FORMAT" adjust=DAYS]DATE[/convert-date]

Container tag (has an end tag). The body is interpolated before use, so ITL
inside it (for example `[item-data ...]`) is expanded first.

## Attributes

| Attribute        | Default              | Description |
|------------------|----------------------|-------------|
| `adjust`         |                      | Amount to shift the date, in days by default (also the first positional). Accepts `adjust_time` expressions like `2 hours`. |
| `format`         | `%d-%b-%Y` (see below) | POSIX `strftime` format string. |
| `raw`            | `0`                  | Emit a compact numeric stamp: `%Y%m%d`, or `%Y%m%d%H%M` when a time is present. |
| `empty`          |                      | Text to return when the body has no date and this option is set (instead of using the current time). |
| `gmt`            | `0`                  | Format in GMT/UTC rather than local time. |
| `locale`         | `mv_locale` scratch  | POSIX `LC_TIME` locale for month/day names. |
| `zerofix`        | `0`                  | Strip leading zeros from one-digit numbers in the output. |
| `compensate_dst` | `0`                  | Compensate the adjusted time for daylight-saving changes. |

Positional order: `adjust`.
Alias: `fmt` for `format`. Alias: `days` for `adjust`.

## Description

The body is parsed as a date in one of two forms: `YYYY-M-D` (dashes,
one- or two-digit month and day), or a run of digits `YYYYMMDD` optionally
followed by `HHMM` and seconds -- all non-digits are stripped first, so
loosely punctuated input still parses. If the body has no digits and `empty`
is set, that text is returned; otherwise the current time is used.

When `adjust` (or `gmt`) is given, the parsed date is converted to an epoch
time, shifted by `adjust` via `adjust_time`, and re-expanded. A bare number in
`adjust` is treated as days.

If no `format` is given, the default is `%d-%b-%Y`, or `%d-%b-%Y %I:%M%p` when
the parsed date carried a time. `raw=1` overrides the format with a numeric
stamp.

Month and weekday names honor `locale` (or the `mv_locale` scratch value); see
[../guides/internationalization.md](../guides/internationalization.md).

## Examples

Format an explicit date:

    [convert-date fmt="%B %e, %Y"]20080701[/convert-date]

produces:

    July 1, 2008

Format the current date with the default format (for example):

    [convert-date][/convert-date]

produces something like:

    01-May-2001

Shift by one day and format:

    [convert-date 1]2001-05-19[/convert-date]

produces:

    20-May-2001

Format an interpolated value from a loop -- the pattern used throughout the
strap demo's order views:

    [convert-date fmt="%b %e, %Y %l:%M %P"][loop-data transactions order_date][/convert-date]

## Notes

`adjust` accepts the same expressions as Interchange's `adjust_time` helper
(`days`, `hours`, `minutes`, etc.), not only whole days. Daylight-saving
transitions can move a day-shifted result by an hour unless `compensate_dst`
is set.

## See also

[db-date](db-date.md),
[../guides/internationalization.md](../guides/internationalization.md),
[../glossary.md](../glossary.md)

## Source

Defined in `code/UserTag/convert_date.tag` (registers the tag `convert-date`).
Implemented by the inline Routine in that file.
