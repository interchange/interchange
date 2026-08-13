# uploadhelper

Renders a file-upload control that saves the uploaded file **to disk** under the
catalog and stores its path in the field. When a value already exists it also
shows a link to the current file and a delete checkbox. Reach for it in a table
editor when a field references an uploaded file kept on the filesystem.

## Usage

    [display type=uploadhelper name=FIELD]

The enclosing HTML form must allow file uploads
(`enctype="multipart/form-data"`), and the file is processed by the
`process_filter` form profile on submit. To choose this widget in the admin UI,
set the `type` field of the field's `mv_metadata` record (keyed
`table::column`) to `uploadhelper`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | derived | HTML field name; also stores the saved file's name. |
| `value` | (looked up) | Current file name; when set, the widget shows a view link and a delete option. |
| `path` / `outboard` | none | Directory (relative to the catalog) the file is stored under and linked from. |
| `umask` | `022` | Umask applied when the uploaded file is written. |
| `cols` / `width` | none | `size` attribute of the file input (characters). |

## Description

When the field is **empty**, `uploadhelper` emits a bare `<input type="file">`
plus two hidden fields — `ui_upload_file_path:NAME` (the target directory) and
`ui_upload_umask:NAME` (the write umask) — that tell the upload handler where
and how to save the file.

When the field **already has a value**, the widget additionally renders a link
to the existing file (through the admin `do_view` action under the `path`), a
`ui_upload_file_delete:NAME` checkbox for removing it, and hidden fields
carrying the current name so an unchanged record round-trips. The actual saving
and deletion are performed by the `process_filter` profile, not by the widget
itself.

Use [uploadblob](uploadblob.md) instead when the file should be stored in a
database BLOB rather than on disk.

## Examples

An empty field:

    [display type=uploadhelper name=logo]

renders:

    <INPUT TYPE=hidden NAME="ui_upload_file_path:logo" VALUE="">
    <INPUT TYPE=file NAME="logo">
    <INPUT TYPE=hidden NAME="ui_upload_umask:logo" VALUE="022">

With a stored file and an upload directory, the control also shows the current
file as a link followed by a delete checkbox:

    [display type=uploadhelper name=logo value="brand.png" path="images/logos"]

renders (trimmed): a `<A HREF=...>brand.png</A>` link, a
`<input type="checkbox" name="ui_upload_file_delete:logo" value="1">` delete
control, and the `<input type="file">` plus hidden path/name/umask fields.

## Notes

- File upload must be enabled on the surrounding form
  (`enctype="multipart/form-data"`), and the widget relies on the
  `process_filter` form profile to store or delete the file on submit.

## See also

- [uploadblob](uploadblob.md) — store the upload in a database BLOB instead
- [imagehelper](imagehelper.md) — image-oriented upload helper

## Source

Defined in `code/Widget/uploadhelper.widget` (routine inline in that file); the
view link is built with `Vend::Interpolate::tag_area`.
