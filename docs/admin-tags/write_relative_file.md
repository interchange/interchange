# write_relative_file

Write the tag's body to a file inside the catalog directory, creating any
missing parent directories. Reach for it from admin pages that need to save
generated content (a template, an export, a log) to a catalog-relative path.

This tag is part of the administrative UI toolset: it is loaded from
`code/UI_Tag/` when the back-office UI is enabled, and is not a storefront
tag. It performs an unconditional write, so it is meant for trusted admin
pages, not for pages exposed to shoppers.

## Syntax

    [write_relative_file file=path]CONTENT[/write_relative_file]
    [write_relative_file path]CONTENT[/write_relative_file]

Container tag (it has an end tag and writes its body). The body is passed
verbatim; it is not interpolated as Interchange Tag Language (ITL) before
being written unless you interpolate it yourself. The tag's own return value
(empty on success, or the value from the underlying write) is reparsed as ITL
by default.

The tag name is registered as `write-relative-file`; Interchange treats
hyphens and underscores in tag names interchangeably, so
`[write_relative_file]` and `[write-relative-file]` are the same tag.

## Attributes

| Attribute         | Default | Description |
|-------------------|---------|-------------|
| `file`            | none    | Path to write, relative to the catalog directory. Required. Positional parameter 1. |
| `auto_create_dir` | `1`     | Create missing parent directories before writing. |
| `umask`           | inherited | Umask applied to the created file, passed through to the writer. |

Positional order: `file`.

Because the tag declares `addAttr`, any other attribute is forwarded to the
underlying `Vend::File::writefile` call (for example `umask`).

## Description

`[write_relative_file]` hands `file` and the tag body to Interchange's file
writer. Before writing, it validates the path with
`Vend::File::allowed_file($file, 1)`: the path must pass the catalog's file
controls (it must be relative and inside the catalog, subject to
[NoAbsolute](../config/NoAbsolute.md) and related directives). If the check
fails, the tag returns undef and writes nothing.

The file is opened for truncation (`>`), so an existing file is overwritten,
not appended to. `auto_create_dir` defaults to on, so writing to a path like
`logs/reports/today.txt` creates the `logs/reports` directory if it does not
exist.

Because the body is not interpolated by default, ITL in the content is
written literally. If you need the content interpolated first, wrap it in
[interpolate](../guides/templating.md) or build it with
[tmp](../tags/tmp.md)/[calc](../tags/calc.md) and pass the result.

## Examples

Write a fixed string to a catalog-relative file:

    [write_relative_file logs/test]Sample content[/write_relative_file]

Write into a subdirectory that does not exist yet (it is created because
`auto_create_dir` defaults on):

    [write_relative_file file=reports/daily/summary.txt]
    Orders today: [scratch order_count]
    [/write_relative_file]

Here the `[scratch ...]` reference is written verbatim unless you interpolate
the body first. To store the resolved value, interpolate before writing:

    [tmp report][scratch order_count][/tmp]
    [write_relative_file file=reports/daily/count.txt][scratch report][/write_relative_file]

## Notes

- The write is unconditional and silent; there is no confirmation output.
  Check the return value or the file if you need to confirm success.
- Path validation is the only guard. Keep this tag on admin-only pages.

## See also

- [write_shipping](write_shipping.md) — write the shipping configuration file
- [read_shipping](read_shipping.md) — read a shipping configuration file
- [File control](../config/FileControl.md) and the
  [security guide](../guides/security.md) for catalog file access rules

## Source

Defined in `code/UI_Tag/write_relative_file.coretag` as an inline Routine.
The routine calls `Vend::File::allowed_file` and `Vend::File::writefile`.
