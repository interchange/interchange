# backup_file

Copy a file into the catalog's `backup/` tree, rotating any previous backup of
the same file so older copies are preserved. Used by the admin UI before it
overwrites a page, component, or configuration file. This tag is part of the
Interchange admin UI toolset (the tags in `code/UI_Tag/`, loaded when the admin
UI feature is enabled), not a storefront tag.

## Syntax

    [backup_file file]

Standalone tag (no end tag). The return value is `1` on success or empty on
failure; it is not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `file`    | none    | Path (relative to the catalog directory) of the file to back up. |

Positional order: `file`.

The tag declares `AddAttr`, but the routine uses only `file`.

## Description

`[backup_file]` computes a destination of `backup/FILE`, creating the backup
subdirectory tree with `File::Path::mkpath` if needed. If a backup of that file
already exists, it first calls `UI::Primitive::rotate` to shift the existing
backups (keeping up to ten numbered generations), then copies the current file
into place with `File::Copy::copy`.

On success the tag returns `1`. On any failure it stores the error message in
the scratch variable `ui_error`, logs it, and returns nothing (undef).

## Examples

Back up a page file before saving edits to it:

    [backup_file file="pages/index.html"]

Guard a save with the result:

    [if type=explicit compare="[backup_file file='catalog.cfg']"]
      Backup made.
    [else]
      Backup failed -- see the error log.
    [/if]

## Notes

The backup directory layout mirrors the source path under `backup/`, so
`pages/index.html` is backed up to `backup/pages/index.html` with rotated
generations (`index.html+`, and so on) alongside it. The rotation depth is the
`rotate` routine's default of ten.

## See also

- [backup_database](backup_database.md)
- [cp](cp.md)
- [write_relative_file](write_relative_file.md)
- Concepts: [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/backup_file.coretag` (registered as the tag
`backup-file`; ITL treats hyphen and underscore in tag names as equivalent).
Implemented by the inline Routine, which uses `File::Copy`, `File::Path`, and
`UI::Primitive::rotate`.
