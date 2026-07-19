# strftime

Formats a UNIX timestamp as a human-readable date/time string.

## Syntax

    [filter strftime]SECONDS[/filter]
    [filter strftime.FORMAT]SECONDS[/filter]
    [value name=field filter="strftime.FORMAT"]

`SECONDS` is a UNIX time value (seconds since the epoch, 1970-01-01 UTC).
`FORMAT` is a dotted `POSIX::strftime` format argument.

## Description

The filter interprets the value as a UNIX timestamp, converts it to the
server's local time, and formats it. With a format argument the result is
produced by `POSIX::strftime`; with no format it returns
`scalar localtime`, for example `Fri Dec 16 15:04:33 2005`.

The format is taken from the dotted arguments. If several dotted arguments
are present they are joined with spaces, so a format that itself contains
dots is not preserved literally -- each `.` between conversion specifiers
becomes a space. Give the format as a single dotted token without embedded
dots (for example `strftime.%Y-%m-%d`) for predictable results.

The output is in the server's local timezone, so the exact string depends
on the machine's timezone setting.

## Examples

For the timestamp `1134745473`, with no format:

    [filter strftime]1134745473[/filter]

produces (in UTC):

    Fri Dec 16 15:04:33 2005

With an ISO-style date format:

    [filter strftime.%Y-%m-%d]1134745473[/filter]

produces:

    2005-12-16

The epoch itself, timestamp `0`:

    [filter strftime]0[/filter]

produces (in UTC):

    Thu Jan  1 00:00:00 1970

## See also

[convert_date](convert_date.md), [datetime2epoch](datetime2epoch.md),
[duration](duration.md); to obtain a timestamp from a date see
[date2time](date2time.md).

## Source

Defined in `code/Filter/strftime.filter`.
