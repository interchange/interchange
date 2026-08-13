# uploadblob

Renders a file-upload control whose contents are stored **directly into a
database BLOB column** rather than written to a file on disk. Reach for it in a
table editor when a field should hold the uploaded file itself (an image, a
PDF) inside the database.

## Usage

    [display type=uploadblob name=FIELD]

The enclosing HTML form must allow file uploads
(`enctype="multipart/form-data"`). To choose this widget in the admin UI, set
the `type` field of the field's `mv_metadata` record (keyed `table::column`) to
`uploadblob`. Its `ExtraMeta` adds two admin settings, `name_to` and
`size_to`, for optionally recording the uploaded file's name and size in other
columns of the same table editor.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | derived | HTML field name; also the database column the BLOB is stored in. |
| `cols` / `width` | none | `size` attribute of the file input (characters). |
| `name_to` | none | Another column in which to store the uploaded file's name. |
| `size_to` | none | Another column in which to store the uploaded file's size. |
| `prepend` / `append` | empty | Literal HTML placed before/after the control. |

## Description

`uploadblob` emits an `<input type="file">` plus the hidden fields the
Interchange upload machinery needs to route the file into a BLOB column:
`mv_data_file_field` (the target column), `mv_data_file_path`, and
`mv_data_file_oldfile`. When `name_to` or `size_to` is given, extra hidden
fields (`mv_data_file_name_to_NAME`, `mv_data_file_size_to_NAME`) tell the
handler where to record the file's name and size. On submit, the server reads
the uploaded content and writes it to the named column.

Use [uploadhelper](uploadhelper.md) instead when the file should be saved to
disk under the catalog rather than stored in the database.

## Examples

    [display type=uploadblob name=image]

renders:

    <INPUT TYPE=hidden NAME="mv_data_file_field" VALUE="image">
    <INPUT TYPE=hidden NAME="mv_data_file_path" VALUE="">
    <INPUT TYPE=hidden NAME="mv_data_file_oldfile" VALUE="">
    <INPUT TYPE=file NAME="image">

Recording the file name and size in sibling columns:

    [display type=uploadblob name=image name_to=image_name size_to=image_size]

adds, ahead of the file input:

    <INPUT TYPE=hidden NAME="mv_data_file_name_to_image" VALUE="image_name">
    <INPUT TYPE=hidden NAME="mv_data_file_size_to_image" VALUE="image_size">

## See also

- [uploadhelper](uploadhelper.md) — upload to a file on disk instead of a BLOB
- [imagehelper](imagehelper.md) — image-oriented upload helper

## Source

Defined in `code/Widget/uploadblob.widget` (routine and `ExtraMeta` inline in
that file).
