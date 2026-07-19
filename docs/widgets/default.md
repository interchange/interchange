# default

The fallback widget: it renders a plain HTML control from a built-in template
and is what Interchange uses when a requested widget type has no routine of its
own. You rarely name it directly.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws the
control for a field. Attribute values shown here are Interchange Tag Language
(ITL) tag attributes.

## Usage

    [display type=text name=FIELD value="..."]

You normally invoke it implicitly by choosing a template-only type such as
`text`, `textarea`, `password`, `hidden`, `file`, or `value` — or by leaving
`type` off entirely, in which case a plain text input is produced. Its
`CodeDef` marks it `Visibility private`, so the admin widget picker does not
offer it as a selectable widget.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | (required) | Form variable |
| `value` | (empty) | Current value, HTML-encoded into the control |
| `type` | `text` | Which built-in template to render |
| `cols` / `width` | (none) | Input `size` (or textarea columns) |
| `rows` / `height` | (none) | Textarea rows |
| `maxlength` | (none) | Input `maxlength` |
| `extra` | (none) | Literal attributes appended to the tag |
| `prepend` / `append` | (empty) | Markup emitted before/after the control |

## Description

`default` maps to `Vend::Form::template_sub`, which fills the template named by
the current type from the `%Template` table in `lib/Vend/Form.pm`
(`text`, `textarea`, `password`, `hidden`, `file`, `filetext`, `hiddentext`,
`value`, …). If no template matches the type it uses the `text` template, which
is the module's registered default. This is also the final fallback inside the
widget dispatcher: when a named widget has no routine and none is registered,
`display` falls back to the `default` widget (or directly to `template_sub`),
so an unknown or plain type still produces a usable input rather than an error.

## Examples

A plain text input (type defaults to `text`, so these are equivalent):

    [display name=comment value="[value comment]"]
    [display type=text name=comment value="[value comment]"]

Rendered HTML:

    <input type="text" name="comment" value="">

A password field of a given width:

    [display type=password name=passwd cols=20]

produces:

    <input type="password" name="passwd" value="" size="20">

## See also

- [text](text.md), [textarea](textarea.md), [value](value.md) — types this
  widget renders through their templates
- [display](../admin-tags/display.md), [widget](../admin-tags/widget.md)

## Source

Defined in `code/Widget/default.widget`; maps to `Vend::Form::template_sub`
in `lib/Vend/Form.pm`, which draws from the `%Template` table in the same file.
