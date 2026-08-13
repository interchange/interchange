# convert_date

Formats a date value with a `strftime`-style format string, by calling the
[convert-date](../tags/convert-date.md) tag.

## Syntax

    [filter convert_date.FORMAT]DATE[/filter]
    [value name=field filter="convert_date.FORMAT"]

The dotted argument `FORMAT` is a `strftime` format string. Because a
format containing spaces must survive the filter's word-splitting, quote
it: `convert_date."%B %e, %Y"`.

## Description

The filter passes its input date and the `FORMAT` argument to the
`convert-date` tag and returns the result.
The tag accepts a date either as `YYYY-MM-DD` or as a run of digits
(`YYYYMMDD`, optionally followed by `HHMM` and `SS`) and formats it with
the given `strftime` specifiers (see the glossary
[time](../glossary.md) entry for the specifier list).

The one behavioral difference from the tag: called with an empty or
invalid date, this filter returns the empty string, whereas the
`convert-date` tag would default to the current time.

## Examples

Extracting the year:

    [filter convert_date.%Y]20070516[/filter]

produces:

    2007

A long formatted date (note the quoting, because the format contains
spaces and a comma):

    [filter convert_date."%B %e, %Y"]20070516[/filter]

produces:

    May 16, 2007

## See also

- [convert-date](../tags/convert-date.md) tag
- [strftime](strftime.md)
- [datetime2epoch](datetime2epoch.md)
- [internationalization guide](../guides/internationalization.md)

## Source

Defined in `code/Filter/convert_date.filter`, which calls the
`convert-date` user tag (`code/UserTag/convert_date.tag`).
