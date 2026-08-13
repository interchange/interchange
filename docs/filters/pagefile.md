# pagefile

Strips leading `.` and `/` characters so a value is safe to use as an
Interchange page name.

## Syntax

    [filter pagefile]TEXT[/filter]
    [value name=page filter="pagefile"]

## Description

The filter removes any run of leading dot and slash characters from the
front of the value (the regular expression `s:^[./]+::`). This prevents a
submitted page name from reaching outside the pages directory with a
leading `/` absolute path or `../` traversal, and normalizes a leading
`./`.

Only leading `.` and `/` characters are removed; dots and slashes elsewhere
in the value are left alone, so `pagefile` normalizes the start of the name
rather than fully sanitizing an arbitrary path. For general filename safety
see [filesafe](filesafe.md).

## Examples

    [filter pagefile]./report[/filter]

produces:

    report

Leading traversal characters are stripped:

    [filter pagefile]../../ord/basket[/filter]

produces:

    ord/basket

## See also

[filesafe](filesafe.md), [strip_path](strip_path.md)

## Source

Defined in `code/Filter/pagefile.filter`.
