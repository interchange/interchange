# mime_type

Returns the MIME type for a filename, chosen from its extension.

## Syntax

    [filter mime_type]FILENAME[/filter]
    [value name=field filter="mime_type"]

## Description

The filter passes the input to `Vend::Util::mime_type`, which:

1. Strips everything up to and including the last `.` to get the extension.
2. If there is no extension, returns the catalog's configured default type
   ([MimeType](../config/MimeType.md) `default`) or `text/plain`.
3. Otherwise lower-cases the extension and looks it up, first in the catalog's
   [MimeType](../config/MimeType.md) configuration, then in Interchange's
   built-in table, falling back to the configured default or
   `application/octet-stream`.

The built-in table covers common types, including `jpg`/`jpeg` → `image/jpeg`,
`gif` → `image/gif`, `png` → `image/png`, `htm`/`html` → `text/html`,
`txt`/`asc`/`csv` → `text/plain`, and `xls` → `application/vnd.ms-excel`. Add
or override extensions with the [MimeType](../config/MimeType.md) directive in
`catalog.cfg`.

## Examples

    [filter mime_type]image.jpg[/filter]

produces:

    image/jpeg

A name with no recognized extension falls back to the default type (built-in
default shown):

    [filter mime_type]README[/filter]

produces:

    application/octet-stream

## See also

- [MimeType](../config/MimeType.md)
- [filesafe](filesafe.md)
- [strip_path](strip_path.md)

## Source

Defined in `code/Filter/mime_type.filter`; the routine calls
`Vend::Util::mime_type` in `lib/Vend/Util.pm`.
