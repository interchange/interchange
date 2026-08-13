# multiple

Renders a multi-select list box: a `<select multiple>` showing the options as a
scrolling list from which several values can be chosen at once.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws it for
a field. Attribute values shown here are Interchange Tag Language (ITL) tag
attributes.

## Usage

    [display type=multiple name=FIELD passed="a=Apple,b=Banana,c=Cherry"]

To select it in the admin UI, set the field's `mv_metadata` `type` column to
`multiple`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | (required) | Form variable that receives the selected values |
| `value` | (empty) | Current value(s); each matching option is selected |
| `passed` / `lookup` / `lookup_query` | (none) | Source of the option list |
| `rows` / `height` | (none) | Visible rows (`size`) of the list box |
| `cols` | (none) | Truncate labels to this many characters |

This widget is declared `Multiple`, so several selected values are stored as a
multi-valued field.

## Description

`multiple` maps to `Vend::Form::dropdown`. Because the type is `multiple`, the
dispatcher sets the `multiple` attribute on the `<select>`, so the browser
renders it as a scrolling list rather than a single-line dropdown and lets the
user pick more than one option. An option is pre-selected when the current value
contains its value (the multi-value match tolerates comma, whitespace, or null
separators). Options are resolved from `passed`, a `lookup`/`lookup_query`, or
the field's column data, exactly as for [select](select.md); an option value of
the form `~~Text~~` becomes an `<optgroup>` heading.

## Examples

A three-option multi-select with two chosen:

    [display type=multiple name=tags rows=4 value="new,sale"
             passed="new=New,sale=On Sale,clear=Clearance"]

Rendered HTML (trimmed):

    <select name="tags" size="4" multiple>
    <option value="new" SELECTED>New</option>
    <option value="sale" SELECTED>On Sale</option>
    <option value="clear">Clearance</option>
    </select>

## See also

- [select](select.md) — single-choice dropdown built on the same routine
- [checkbox](checkbox.md) — multi-value control as checkboxes
- [movecombo](movecombo.md) — collect picks into a text box

## Source

Defined in `code/Widget/multiple.widget`; maps to `Vend::Form::dropdown` in
`lib/Vend/Form.pm`.
