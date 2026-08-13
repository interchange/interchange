# strip_path

Removes every directory component from a path, leaving just the file name.

## Syntax

    [filter strip_path]PATH[/filter]
    [value name=field filter="strip_path"]

`strip_path` takes no arguments.

## Description

The filter deletes everything up to and including the last forward slash (`/`)
or backslash (`\`) in the value, so it works on both Unix-style and
Windows-style paths. Because the match is greedy, only the final path segment
survives. A value with no slash or backslash is returned unchanged. This is
useful for turning an uploaded file's full client path into a bare file name.

## Examples

Unix path:

    [filter strip_path]/var/lib/interchange/logo.png[/filter]

produces:

    logo.png

Windows path:

    [filter strip_path]C:\Users\me\Desktop\invoice.pdf[/filter]

produces:

    invoice.pdf

A value with no separators is unchanged:

    [filter strip_path]report.csv[/filter]

produces:

    report.csv

## See also

- [filesafe](filesafe.md) — sanitize a value for use as a file name
- [pagefile](pagefile.md) — strip leading `./` path characters from a page name
- [upload](upload.md) — read the contents of an uploaded file

## Source

Defined in `code/Filter/strip_path.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
