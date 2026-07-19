# duration

Adds a duration to a start date/time and returns the resulting
`YYYYMMDDHHMMSS` end date/time.

## Syntax

    [filter op=duration.STARTVAR.DURVAR /]
    [filter duration.STARTVAR.DURVAR.EXTRA...]START[/filter]

`duration` is driven entirely by its dotted arguments. The first argument
names the CGI variable holding the start date, the second names the CGI
variable holding the duration; any further dotted arguments are treated as
extra words of a literal duration.

## Description

The filter computes an end date/time from a start and a duration:

- **Start.** The value of the CGI variable named by the first argument is
  used as the start date; if that variable is empty, the filter body is
  used instead. The start date is parsed with the same US-style rules as
  [date2time](date2time.md) (`MM/DD/YYYY` with optional `:hhmm`, or a bare
  `YYYYMMDDHHMM` digit string).
- **Duration.** The value of the CGI variable named by the second argument
  is used as the duration string (for example `12 hours`, `3 days`). If
  that variable is empty and the second argument is itself all digits, the
  second argument plus any extra dotted arguments are joined with spaces to
  form the duration — this is what lets you write the duration inline as
  `duration.-dummy.12.hours`.

If no duration can be determined, the filter returns its input unchanged.
The start is converted to epoch seconds (`Time::Local`, server local time
zone), advanced by the duration with `adjust_time`, and formatted back as
`YYYYMMDDHHMMSS` with `strftime`.

## Examples

Using two CGI variables — a start of Feb 12 2005 08:00 and a duration of
12 hours:

    [cgi name=start_date set=200502120800 hide=1]
    [cgi name=length     set="12 hours"   hide=1]
    [filter op=duration.start_date.length /]

produces:

    20050212200000

The same result with the duration written inline. Here `-dummy` is a
nonexistent CGI variable, so the start comes from the filter body:

    [filter duration.-dummy.12.hours]200502120800[/filter]

produces:

    20050212200000

## See also

- [datetime2epoch](datetime2epoch.md)
- [date2time](date2time.md)
- [date_change](date_change.md)

## Source

Defined in `code/Filter/duration.filter`. Uses `Time::Local` and
`Vend::Util::adjust_time` (`lib/Vend/Util.pm`).
