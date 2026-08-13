# datetime2epoch

Converts a date, with an optional time, to the number of seconds since the
Unix epoch (1970-01-01 00:00:00).

## Syntax

    [filter datetime2epoch]DATE[/filter]
    [value name=field filter="datetime2epoch"]

`datetime2epoch` takes no arguments. It can be used anywhere a filter is
accepted: the [filter](../tags/filter.md) tag, the `filter=` attribute
of tags such as [value](../tags/value.md), and the `filter` setting of a
form widget.

## Description

The filter accepts either of two input forms:

- US style: `MM/DD/YY` or `MM/DD/YYYY` (dashes also work as separators),
  optionally followed by `:hh`, `:hh:mm`, or `:hh:mm:ss`.
- ISO / SQL style: `YYYY-MM-DD`, optionally followed by a `T` or space and
  `hh`, `hh:mm`, or `hh:mm:ss`.

It normalizes the input to an ISO datetime and then computes the epoch
seconds with `Time::Local::timelocal`, interpreting the value in the
server's local time zone. A two-digit year below `50` is treated as
`20xx`, otherwise as `19xx`. An unspecified month or day defaults to `01`;
unspecified hours, minutes, or seconds default to `00`. NUL characters in
the input are stripped first.

If the assembled date is not a valid time, the filter logs an error and
returns `0`.

This filter supersedes [date2time](date2time.md), which is deprecated and
mishandles several inputs.

## Examples

The epoch numbers below are computed in the UTC time zone; the exact value
depends on the server's time zone.

    [filter datetime2epoch]01/01/2008[/filter]

produces:

    1199145600

With a time component:

    [filter datetime2epoch]01-01-08:10:45[/filter]

produces:

    1199184300

ISO / MySQL timestamp form:

    [filter datetime2epoch]2008-01-01 10:45:00[/filter]

produces:

    1199184300

## See also

- [date2time](date2time.md)
- [date_change](date_change.md)
- [strftime](strftime.md)
- [convert_date](convert_date.md)

## Source

Defined in `code/Filter/datetime2epoch.filter`. Uses the `Time::Local`
Perl module.
