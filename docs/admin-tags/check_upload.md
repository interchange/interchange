# check_upload

Move a file that was uploaded into the catalog's `upload/` directory into the
product-data directory, so an admin-uploaded table file is picked up by
Interchange's file-based import. This tag is part of the Interchange admin UI
toolset (the tags in `code/UI_Tag/`, loaded when the admin UI feature is
enabled), not a storefront tag.

## Syntax

    [check_upload file]
    [check_upload file same]

Standalone tag (no end tag). The return value is an empty string on success or
a short error message on failure; it is not reparsed as Interchange Tag
Language (ITL).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `file`    | none    | Basename of the file inside `upload/` to move into the product directory. |
| `same`    | false   | When true, copy under the exact same name (a full replacement). When false, append `+` to the destination name. |

Positional order: `file`, `same` (two positional parameters).

## Description

If `upload/FILE` exists and is non-empty, `[check_upload]` copies it into the
catalog's `ProductDir` and then removes the upload copy. The destination name
is `FILE` when `same` is true, or `FILE+` (a trailing `+`) when `same` is false
or unset.

On a copy failure it returns the string `Couldn't copy uploaded file!`;
otherwise it returns an empty string. If `upload/FILE` is missing or empty, the
tag does nothing and returns an empty string.

## Examples

Move an uploaded `products.txt` into the product directory as an update file:

    [check_upload products.txt]

Replace the existing file outright, under the same name:

    [check_upload products.txt 1]

## Notes

The trailing `+` on the destination name (used when `same` is false) is
Interchange's convention for a file the import machinery should treat as an
incremental update rather than a full table replacement. The exact handling of
a `+`-suffixed file is part of the database import subsystem and is not
restated here; treat `same=1` as "replace the file as named" and the default as
"drop in an update file." This is honest uncertainty about the downstream
import semantics, not about what the tag itself writes.

The tag reads from a fixed `upload/` directory and writes to `ProductDir`;
neither path is configurable through attributes.

## See also

- [cp](cp.md)
- [backup_database](backup_database.md), [import_fields](import_fields.md)
- Concepts: [databases](../guides/databases.md), [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/check_upload.coretag` (registered as the tag
`check-upload`; ITL treats hyphen and underscore in tag names as equivalent).
Implemented by the inline Routine, which uses `File::Copy`.
