# imagedir

Renders a picker listing the image files found in a directory on the server,
so a field can be set to one of the existing images. It is a wrapper over the
[combo](combo.md) widget.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws the
control for a field. Attribute values shown here are Interchange Tag Language
(ITL) tag attributes.

## Usage

    [display type=imagedir name=FIELD dir=DIRECTORY]

To select it in the admin UI, set the field's `mv_metadata` `type` column to
`imagedir` (the widget also exposes a "Follow Symlinks" yes/no option there).

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | (required) | Form variable for the chosen filename |
| `value` | (empty) | Pre-selected filename |
| `dir` / `outboard` | (required) | Directory to scan for images |
| `suffix` / `options` | image extensions | Extensions or a regex to match; a bare list like `gif,png` becomes `\.(gif|png)$` |
| `variant` | `combo` | Underlying widget type to render the list as |
| `follow_symlinks` | off | Descend into symlinked directories while scanning |

The default extension pattern matches `gif`, `jpg`, `jpeg`, and `png` in upper
or lower case.

## Description

`imagedir` uses `File::Find` to walk `dir`, collecting files whose names match
the suffix pattern, and builds the option list as `=None` plus the sorted file
names (paths are made relative to `dir`). It then renders that list through the
shared `Vend::Form::display` dispatcher as the chosen `variant` — a
[combo](combo.md) by default, so the result is a `<select>` of filenames plus
an add-value text box. If `dir` is not a directory the widget renders nothing.

The listed files depend on the server's filesystem, so no fixed option list is
shown here.

## Examples

Pick an item image from the catalog's image directory:

    [display type=imagedir name=image dir="images/items" value="[value image]"]

Rendered HTML (shape only — real `<option>`s come from the directory):

    <input type="text" name="image" size="" value="">
    <select name="image">
    <option value="None">None</option>
    <option value="widget-01.jpg">widget-01.jpg</option>
    ...
    </select>

Restrict to PNG files and render as a plain dropdown:

    [display type=imagedir name=image dir="images/items" suffix=png variant=select]

## See also

- [combo](combo.md) — the default underlying widget
- [imagehelper](imagehelper.md), [uploadhelper](uploadhelper.md) — upload a new
  image instead of picking an existing one
- [databases](../guides/databases.md)

## Source

Defined in `code/Widget/imagedir.widget`; its inline routine scans with
`File::Find` and finishes with `Vend::Form::display` in `lib/Vend/Form.pm`.
