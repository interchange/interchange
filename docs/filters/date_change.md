# date_change

Normalizes a date (and optional time) into a compact `YYYYMMDDHHMM`
string, chiefly to store the value produced by a date-selection widget.

## Syntax

    [filter date_change]DATE[/filter]
    [filter date_change.OPTION]DATE[/filter]
    [value name=field filter="date_change"]

Zero or more dotted `OPTION` flags change the output format; see below.

## Description

The filter accepts a date in either US order (`MM/DD/YYYY` or `MM/DD/YY`,
with `/` or `-` separators) or ISO order (`YYYY-MM-DD`), optionally
followed by a time. The leading field's length decides the order: four
digits means ISO (year first), otherwise US (month first). A two-digit
year below `50` becomes `20xx`, otherwise `19xx`. HTML entities in the
input are decoded and NUL characters stripped before parsing.

By default the output is `YYYYMMDD` with any time appended as `HHMM`. The
dotted option flags are:

- `iso` — output ISO format `YYYY-MM-DDThh:mm:ss`.
- `common` — output `YYYY-MM-DD hh:mm:ss` (space instead of `T`).
- `no_time` — drop the time portion, output the date only.
- `undef` — for an empty date (all zeroes or nothing at all) return
  undefined (which DBI stores as SQL `NULL`) rather than defaulting.

Without `undef`, an empty date is **not** rejected here; the parsing regex
simply fails to match and the original input is returned unchanged.

The filter is most often attached to a date-selection field so the
widget's `MM/DD/YYYY` value is stored in a sortable form.

**Time gotcha:** a time given as `:hhmm` is left-padded to four digits, so
supplying only two digits fills the *minutes*, not the hours — `:30`
becomes `00:30`, not `30:00`.

## Examples

ISO date, no time:

    [filter date_change]2005-01-01[/filter]

produces:

    20050101

US date with a time:

    [filter date_change]05-29-2005:1536[/filter]

produces:

    200505291536

ISO output format:

    [filter date_change.iso]2005-01-01[/filter]

produces:

    2005-01-01

Dropping the time:

    [filter date_change.no_time]2005-01-01:10[/filter]

produces:

    20050101

With `undef`, an all-zero date yields nothing (an SQL `NULL` when stored):

    [filter date_change.undef]0000-00-00[/filter]

produces the empty string.

## See also

- [datetime2epoch](datetime2epoch.md)
- [date2time](date2time.md)
- [convert_date](convert_date.md)
- [date](../widgets/date.md) widget

## Source

Defined in `code/Filter/date_change.filter`.
