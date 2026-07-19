# movecombo

Renders a dropdown of options beside a text box: choosing an option appends its
value into the text box, letting you assemble a list by picking any or all of
the options. Use it to build a comma- or newline-separated set from a
controlled vocabulary.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws it for
a field. Attribute values shown here are Interchange Tag Language (ITL) tag
attributes.

## Usage

    [display type=movecombo name=FIELD passed="a=Apple,b=Banana"]

To select it in the admin UI, set the field's `mv_metadata` `type` column to
`movecombo`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | (required) | Form variable of the text box that collects values |
| `value` | (empty) | Current contents of the text box |
| `passed` / `lookup` / `lookup_query` | (none) | Source of the dropdown options |
| `rows` / `height` | `1` | Rows of the collector; more than 1 makes it a `<textarea>` |
| `cols` / `width` | `16` | Width of the collector |
| `reverse` | off | Put the text box before the dropdown |
| `replace` | off | Replace rather than append (see [movecombo_replace](movecombo_replace.md)) |
| `o_template` | (built-in) | Custom template for the collector control |

## Description

`movecombo` maps to `Vend::Form::movecombo`. It draws a normal
[dropdown](select.md) whose form name is prefixed with `X` (so it is not
submitted) and attaches an `onChange` handler calling the JavaScript
`addItem(select, textbox, usenl, only)`. That function copies the selected
option's value into the collector control, which carries the real field `name`
and *is* submitted. When `rows` is greater than 1 the collector is a
`<textarea>` and values are separated by newlines (`usenl`); otherwise it is a
one-line text input.

The `addItem` JavaScript is not emitted by the widget; it is provided by the
admin UI's shared scripts, so using `movecombo` on a storefront page requires
supplying an `addItem` function yourself.

## Examples

Pick several features into a comma-separated text box:

    [display type=movecombo name=features passed="gift=Gift wrap,rush=Rush ship,card=Gift card"]

Rendered HTML (trimmed):

    <select name="Xfeatures" onChange="addItem(this.form['Xfeatures'],this.form['features'],0,0)">
    <option value="gift">Gift wrap</option>
    <option value="rush">Rush ship</option>
    <option value="card">Gift card</option>
    </select>
    <input type="text" size="16" name="features" value="">

Collect into a multi-line textarea, box first:

    [display type=movecombo name=features rows=4 cols=30 reverse=1
             passed="gift=Gift wrap,rush=Rush ship"]

## See also

- [movecombo_replace](movecombo_replace.md) — one-value variant
- [combo](combo.md) — dropdown plus free-text add box
- [multiple](multiple.md), [checkbox](checkbox.md) — other multi-value controls

## Source

Defined in `code/Widget/movecombo.widget` (the same file defines
[movecombo_replace](movecombo_replace.md)); maps to `Vend::Form::movecombo` in
`lib/Vend/Form.pm`.
