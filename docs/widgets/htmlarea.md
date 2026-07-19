# htmlarea

Renders a rich-text (WYSIWYG) editor in place of a plain `<textarea>` on
supported browsers, falling back to an ordinary textarea otherwise. Use it for
fields that hold HTML content edited by non-technical users.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws the
control for a field. Attribute values shown here are Interchange Tag Language
(ITL) tag attributes.

## Usage

    [display type=htmlarea name=FIELD height=NN width=NNN]

To select it in the admin UI, set the field's `mv_metadata` `type` column to
`htmlarea`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | (required) | Form variable for the edited HTML |
| `value` | (empty) | Current content (encoded if it contains `<`) |
| `height` | (none) | Editor height in rows/pixels (non-digits stripped) |
| `width` | (none) | Editor width in columns/pixels (non-digits stripped) |
| `flavour` | `HTMLAREA_FLAVOUR` variable, else `htmlarea` | Which editor to use: `htmlarea` or `fckeditor` |
| `htmlarea_config` | (none) | With `fckeditor`, name of a JS function called with the editor object to configure it |
| `anchor_class` / `anchor_style` | style `font-size: smaller` | CSS for the toggle anchor |
| `text_class` / `text_style` | (none) | CSS for the text area |

## Description

`htmlarea` supports two editor "flavours": **htmlarea** (the HTMLArea editor)
and **fckeditor** (FCKeditor). The flavour is chosen by the `flavour` option or
the [HTMLAREA_FLAVOUR](../variables/) variable, defaulting to `htmlarea`. On the
first use per page the widget injects the editor's script tags into the
`meta_header` scratch value; the editor's base path comes from the
[HTMLAREA_PATH](../variables/) variable (default `/htmlarea/` or `/fckeditor/`),
and the interface language from [HTMLAREA_LANG](../variables/) or the current
locale.

The widget emits a `<textarea>` plus the JavaScript that replaces it with the
editor; if the browser cannot run the editor, the textarea remains fully
usable. The editor software itself is not bundled — you must install HTMLArea
or FCKeditor under your DocumentRoot (or point `HTMLAREA_PATH` at it). Using it
outside the admin UI additionally requires the editor script tags in the page
`<head>`, as the widget's own documentation block describes.

## Examples

A rich-text field 10 rows by 400 wide:

    [display type=htmlarea name=comment value="[value comment]" height=10 width=400]

Rendered HTML (trimmed; the injected header/script blocks are omitted):

    <textarea id="htmlarea_comment" rows="10" cols=400 name="comment"></textarea>
    <script>
        HTMLArea.replace('htmlarea_comment');
    </script>

Use FCKeditor with a named configuration function:

    [display type=htmlarea name=body flavour=fckeditor height=20 width=600
             htmlarea_config="bar"]

    <script>
    function bar (fckobj) {
        fckobj.ToolbarSet = 'Basic';
    }
    </script>

## See also

- [textarea](textarea.md) — the plain control this enhances
- [HTMLAREA_FLAVOUR, HTMLAREA_PATH, HTMLAREA_LANG](../variables/) variables
- [content_editor](../admin-tags/) — admin page/content editor

## Source

Defined in `code/Widget/htmlarea.widget`; the routine (and an extensive
`Documentation` POD block) are inline in that file. Requires Interchange 5.0 or
higher.
