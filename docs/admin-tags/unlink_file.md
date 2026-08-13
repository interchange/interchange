# unlink_file

Safely delete a file from within the catalog directory, refusing paths that
escape it or that do not match a required prefix. The admin UI uses it to clean
up temporary and generated files. This tag is part of the admin UI toolset
(registered from `code/UI_Tag/` and loaded only when the administrative
interface is enabled), not a storefront tag.

## Syntax

    [unlink_file name]
    [unlink_file name=path prefix=dir/]

Standalone tag (no end tag). Runs for its side effect (the deletion); it returns
nothing.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | none    | Path of the file to delete, relative to the catalog directory. |
| `prefix`  | `tmp/`  | The filename must begin with this prefix, as a safety measure. |

Positional order: `name`, `prefix`.

## Description

The tag deletes `name` from the catalog root, but only after two safety checks:

1. The path must not be absolute nor contain a `../` traversal (checked with
   `Vend::File::absolute_or_relative`); such paths are silently refused.
2. The path must start with `prefix`. This confines deletions to an intended
   area — by default the catalog's `tmp/` directory.

If either check fails the tag does nothing. When both pass, the file is removed
with Perl's `unlink`. The tag is registered as `unlink_file` and may also be
invoked as `[unlink-file]`.

## Examples

Create a temporary file and then delete it (the [tmp](../tags/tmp.md) wrapper
just suppresses the contained tags' output):

    [tmp]
    [write_relative_file tmp/testfile]
    Hello, World!
    [/write_relative_file]
    [unlink_file tmp/testfile]
    [/tmp]

Delete a file under a non-default prefix (the prefix must match, or nothing
happens):

    [tmp][unlink_file name="logs/tmplog" prefix="logs/"][/tmp]

## Notes

Because the safety check requires the path to begin with `prefix`, deleting a
file outside the default `tmp/` area means passing a `prefix` that the path
matches; a mismatched prefix makes the tag a no-op rather than an error.

## See also

- [write_relative_file](write_relative_file.md)
- [substitute_file](substitute_file.md)
- Concepts: [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/unlink_file.coretag`, registered as the UserTag
`unlink_file` (inline Routine).
