# file

Insert the contents of a file into the page verbatim, with optional
line-ending conversion. Reach for it to pull in a snippet of static text or
markup that lives in its own file under the catalog.

## Syntax

    [file NAME]
    [file NAME TYPE]
    [file name=NAME type=unix]

Standalone tag. The file's contents are returned as-is: they are **not**
reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | (required) | Path of the file to read; positional parameter 1. |
| `type`    | (none)     | Line-ending conversion to apply; positional parameter 2. One of `raw`, `unix`, `mac`, `dos`/`windows`. |

Positional order: `name`, `type`.

## Description

The file is located relative to the catalog root directory, then searched
in any directories named by the [TemplateDir](../config/TemplateDir.md)
directive (catalog and global). Paths that begin with `/` or `..` are
rejected when the administrator has set
[NoAbsolute](../config/NoAbsolute.md). Contents are inserted exactly as
read and are not interpolated for tags.

The `type` value controls newline handling:

- omitted — return the file's contents unchanged (subject to normal locale
  processing on read).
- `raw` — return the bytes with no locale processing applied.
- `mac` — translate newlines to carriage returns.
- `dos` or `windows` — translate newlines to CR/LF pairs.
- `unix` — normalize carriage returns to newlines.

## Examples

Include a static disclaimer file stored in the catalog:

    [file include/disclaimer.txt]

Include a file and force Unix line endings:

    [file name=data/export.txt type=unix]

## Notes

This tag inserts content verbatim; it does not interpolate ITL. To include
a file **and** parse its tags, use the [include](include.md) tag instead.

Prior Interchange documentation described an `[file name=NAME
interpolate=1]` form. The current tag definition accepts only `name` and
`type` (it declares no additional attributes), so `interpolate` has no
effect here — reach for [include](include.md) when you need the contents
parsed.

## See also

[include](include.md), [TemplateDir](../config/TemplateDir.md),
[NoAbsolute](../config/NoAbsolute.md), the
[templating](../guides/templating.md) guide.

## Source

Defined in `code/SystemTag/file.coretag` (inline `Routine`), which wraps
`readfile` in `lib/Vend/File.pm`.
