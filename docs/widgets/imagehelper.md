# imagehelper

Renders an image-upload control for a field: a file input, a link to the
current image (if any), and the hidden fields Interchange's upload machinery
needs to store the file into a directory. Optionally it also offers a dropdown
of existing images in that directory.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws the
control for a field. Attribute values shown here are Interchange Tag Language
(ITL) tag attributes.

## Usage

    [display type=imagehelper name=FIELD image_path="images/items"]

To select it in the admin UI, set the field's `mv_metadata` `type` column to
`imagehelper`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | (required) | Form/file field name; also stored as the target field |
| `value` | (empty) | Current file name |
| `image_path` / `outboard` | (catalog default) | Directory the file is stored in; a trailing `/*` or `/*.ext` also lists existing files |
| `image_base` / `prepend` | (empty) | URL base used to build the link to the current image |
| `name_from_field` | (none) | Column whose value names the stored file (e.g. the SKU) |
| `cols` / `width` | (none) | `size` of the file input |

## Description

`imagehelper` always emits an `<input type="file">` for the field plus hidden
fields (`mv_data_file_field`, `mv_data_file_path`, `mv_data_file_name_from`, and
`mv_data_file_oldfile`) that tell the upload handler where to write the file and
how to name it. When a `value` is present it also renders a link to the current
image. Setting the `mv_force_file_upload` scratch, which the widget does, makes
the enclosing form submit as `multipart/form-data`.

If `image_path` ends in a glob (`/*` or `/*.ext`), the widget lists the matching
files (via `UI::Primitive::list_images`/`list_glob`) into a `<select>` of
`mv_data_file_oldfile`, so the user can keep an existing image instead of
uploading a new one; otherwise that value is carried in a hidden field.

Two conditions must be met for the upload to work: the form must allow file
upload (the widget forces `multipart/form-data`), and the receiving action must
run the `process_filter` order profile that actually saves the file.

## Examples

An image-upload field for a product image:

    [display type=imagehelper name=image image_path="images/items"
             image_base="/foundation/images/items" value="[value image]"]

Rendered HTML when a current image exists (trimmed):

    <a href="/foundation/images/items/images/items/sku01.jpg">sku01.jpg</a>&nbsp;
    <input type="hidden" name="mv_data_file_field" value="image">
    <input type="hidden" name="mv_data_file_name_from" value="">
    <input type="hidden" name="mv_data_file_path" value="images/items">
    <input type="hidden" name="mv_data_file_oldfile" value="sku01.jpg">
    <input type="file" name="image" value="sku01.jpg">

With no current image the leading link is omitted and the file input is empty.

Name the stored file from the record's SKU and offer existing files:

    [display type=imagehelper name=image image_path="images/items/*.jpg"
             name_from_field=sku]

## See also

- [uploadhelper](uploadhelper.md), [uploadblob](uploadblob.md) — general file
  upload widgets
- [imagedir](imagedir.md) — pick an existing image without uploading
- [order-checks](../order-checks/) — the `process_filter` profile that stores
  the file

## Source

Defined in `code/Widget/imagehelper.widget`; the routine is inline and calls
`UI::Primitive::list_images` / `list_glob` and
`Vend::Interpolate::tag_accessories`.
