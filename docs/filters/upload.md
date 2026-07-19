# upload

Replaces a form variable with the contents of the file uploaded for it, when
the submission included a file for that field.

## Syntax

    [input-filter name=fieldname op="upload"]
    [value name=fieldname filter="upload"]

Unlike most filters, `upload` needs to know **which variable** it is filtering,
so it is applied in a context that supplies that name — most commonly the
[input-filter](../tags/input-filter.md) tag or an `mv_data_filter` on a table
write — not through a bare `[filter]` tag. Used with a plain
`[filter upload]...[/filter]`, no variable name is available and the input is
returned unchanged.

## Description

When Interchange receives a multipart form submission, a file input's contents
are held under the field's variable name. The `upload` filter checks, via
`tag_value_extended`, whether the named variable corresponds to an uploaded
file:

- If it does, the filter returns the **contents** of that uploaded file.
- If it does not, the filter returns its input value unchanged (typically the
  field's ordinary string value).

The filter therefore lets you route an uploaded file's bytes into a database
column or scratch value using the same filtering mechanism used for text
fields. For storing a file's raw bytes in a BLOB column through a form, see
also the [uploadblob](../widgets/uploadblob.md) widget.

## Examples

Filter an uploaded field so its file contents replace the CGI value before you
store or use it:

    [input-filter name=attachment op="upload"]

After this runs, the CGI variable `attachment` holds the uploaded file's
contents (or its original value if no file was uploaded for `attachment`).

## Notes

- The filter reads the whole file into memory; it is intended for reasonably
  sized uploads.
- Because a bare `[filter upload]` has no variable-name context, the filter is
  only meaningful where the applying tag passes the field name (input-filter,
  `mv_data_filter`, and similar).

## See also

- [input-filter](../tags/input-filter.md) — apply filters to CGI input by name
- [uploadblob](../widgets/uploadblob.md), [uploadhelper](../widgets/uploadhelper.md)
  — file-upload widgets
- [strip_path](strip_path.md) — reduce a submitted client path to a file name
- [forms](../guides/forms.md) — form handling overview

## Source

Defined in `code/Filter/upload.filter`; reads the upload via
`Vend::Interpolate::tag_value_extended`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
