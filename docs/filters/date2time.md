# date2time

> **Deprecated:** use [datetime2epoch](datetime2epoch.md) instead.

Converts a US-style date-and-time to seconds since the Unix epoch — but
with several quirks that make [datetime2epoch](datetime2epoch.md) the
better choice.

## Syntax

    [filter date2time]DATE[/filter]
    [value name=field filter="date2time"]

`date2time` takes no arguments. It can be used anywhere a filter is
accepted: the [filter](../tags/filter.md) tag, the `filter=` attribute
of tags such as [value](../tags/value.md), and the `filter` setting of a
form widget.

## Description

The filter is intended to turn a date such as `MM/DD/YYYY` (with `/` or `-`
separators), optionally followed by `:hh` or `:hhmm`, into epoch seconds
computed with `Time::Local::timelocal` in the server's local time zone. A
two-digit year below `50` is treated as `20xx`, otherwise `19xx`.

Its behavior has important surprises, which are the reason it is
deprecated:

- **A separated date with no time returns a string, not epoch seconds.**
  When the input contains `/` or `-` separators and no `:time` suffix, the
  filter returns the normalized `YYYYMMDD` date string instead of an epoch
  number. Epoch seconds are only produced when a time is present, or when
  the input is a bare digit string such as `20050101`.
- **It assumes US month-first order.** The first field is taken as the
  month, so an ISO date like `2005-01-01` is misread (the year is treated
  as the month) and produces a nonsense result.

For any new work, use [datetime2epoch](datetime2epoch.md), which handles
both US and ISO forms and always returns epoch seconds.

## Examples

The epoch numbers below are computed in the UTC time zone; the exact value
depends on the server's time zone.

A bare digit date returns epoch seconds:

    [filter date2time]20050101[/filter]

produces:

    1104537600

A slash date with a time returns epoch seconds:

    [filter date2time]01-01-05:1045[/filter]

produces:

    1104576300

But a slash date with no time returns a `YYYYMMDD` string, not epoch
seconds:

    [filter date2time]01/01/2005[/filter]

produces:

    20050101

## See also

- [datetime2epoch](datetime2epoch.md)
- [date_change](date_change.md)
- [duration](duration.md)

## Source

Defined in `code/Filter/date2time.filter`. Uses the `Time::Local` Perl
module.
