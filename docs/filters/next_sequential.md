# next_sequential

Supplies the next unused value in a numbering sequence, drawn from a
database column, when a form field is left blank.

## Syntax

    filter="next_sequential.table.column"
    filter="next_sequential.table.column.qualifier"

The filter is meant to be used as an input filter on a form field (for
example the `filter` attribute of a widget or a `mv_data_fields` filter),
not as a stand-alone `[filter]` block, because it needs the surrounding
field context to work. The dotted arguments name the table and column to
scan, with an optional qualifier column that scopes the search.

## Description

When the incoming value already has a length, the filter returns it
unchanged -- an explicitly supplied number is never overwritten.

When the value is empty, the filter finds the highest existing value in the
named column and returns that value plus one:

    SELECT column FROM table ORDER BY column DESC

The first row's value is incremented and returned. If the table is empty
the filter returns `1`.

If a fourth dotted argument is given, it names a qualifier column. The
scan is then restricted to rows whose qualifier column equals the current
CGI value of that same field, so each group gets its own independent
sequence:

    SELECT column FROM table WHERE qualifier = '[cgi qualifier]' ORDER BY column DESC

Any database error is logged and the filter returns undef.

## Examples

Auto-number a `sort` column in the `survey_q` table when the field is
submitted blank:

    filter="next_sequential.survey_q.sort"

Keep a separate sequence per `sel` value, so each selection group numbers
from 1 upward:

    filter="next_sequential.survey_q.sort.sel"

## Notes

`next_sequential` is marked private (it does not appear in the interactive
filter menus) and is intended for administrative record-entry pages such as
survey builders. With no table argument it falls back to reading the field
from the CGI or `[value]` space, or returns `1`; that path depends on
internal tag context and is rarely used directly.

## See also

[value](value.md), [lookup](lookup.md)

## Source

Defined in `code/Filter/next_sequential.filter`.
