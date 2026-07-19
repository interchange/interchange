# cp

Copy a file, optionally preserving its access/modification times and applying a
specific umask. A small file-management helper used by the admin UI. This tag
is part of the Interchange admin UI toolset (the tags in `code/UI_Tag/`, loaded
when the admin UI feature is enabled), not a storefront tag.

## Syntax

    [cp from=SRC to=DEST]
    [cp from=SRC to=DEST umask=022 preserve_times=1 hide=1]

Standalone tag (no end tag). The return value is the copy status (true/false),
or empty when `hide` is set; it is not reparsed as Interchange Tag Language
(ITL).

## Attributes

| Attribute        | Default | Description |
|------------------|---------|-------------|
| `from`           | none    | Source file to copy. |
| `to`             | none    | Destination file or directory. |
| `umask`          | process default | Octal umask string (for example `022`) applied during the copy, then restored. |
| `preserve_times` | not set | After copying, set the destination's access and modification times from the source. |
| `hide`           | not set | Return an empty string instead of the status. |

Positional order: `from`, `to`.

The tag declares `addAttr`, so `umask`, `preserve_times`, and `hide` are read
from the options hash.

## Description

`[cp]` copies `from` to `to` with `File::Copy::copy`. If `umask` is given, it is
interpreted as octal, applied with `umask()` for the duration of the copy, and
restored afterward. If `preserve_times` is set, the tag reads the source's
atime/mtime with `stat` and applies them to the destination with `utime`.

It returns the operation's status (a true value on success) unless `hide` is
set, in which case it returns an empty string.

## Examples

Copy a page file, discarding the return value:

    [cp from=pages/index.html to=/tmp/ hide=1]

Guard the copy and report failure (from the historic example):

    [either]
      [cp from=pages/index.html to=/tmp/ hide=1]
    [or]
      Copy failed. See error logs for details.
    [/either]

Copy while preserving timestamps:

    [cp from=logs/orders.log to=backup/orders.log preserve_times=1]

## Notes

The `umask` value is passed through Perl's `oct()`, so give it as a string of
octal digits (`022`, not `0o22`).

When `preserve_times` is set but the source's `stat` yields no atime, the tag
reports a false (failed) status even if the copy itself succeeded.

## See also

- [backup_file](backup_file.md), [backup_database](backup_database.md)
- [write_relative_file](write_relative_file.md), [unlink_file](unlink_file.md)
- Concepts: [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/cp.coretag`. Implemented by the inline Routine, which
uses `File::Copy`.
