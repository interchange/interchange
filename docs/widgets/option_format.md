# option_format

Renders a small grid of text inputs for **editing** an option list — one row
per choice, with columns for the value, the label, and a default flag. Reach
for it in the admin table editor when a field stores its own `value=label`
option string and you want a friendly way to maintain it.

## Usage

    [display type=option_format name=FIELD value="v1=Label 1,v2=Label 2"]

To choose this widget in the admin UI, set the `type` field of the field's
`mv_metadata` record (keyed `table::column`) to `option_format`. The current
option string is passed in as the value and unpacked into editable rows.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | derived | HTML field name shared by every input in the grid (the pieces are recombined on submit). |
| `value` | (looked up) | The current option string to edit. |
| `width` | `16` | Character width of the label input (the value input is half this). |
| `height` | `5` | Target number of rows; extra blank rows are always appended for adding new options. |
| `filter` | `option_format` | Filter applied to the value before it is split into rows. |

## Description

`option_format` unpacks the current option string (after running it through the
[option_format](../filters/option_format.md) filter) into `value=label` pairs
and renders an HTML `<table>`. Each row is one choice: a small text input for
the value, a wider text input for the label, and a `<select>` with `no`/
`default` marking whether that choice is the default (a trailing `*` on the
label). A handful of empty rows follow so new options can be added. Every input
in the grid shares the field name, so on submit the pieces are recombined —
via the matching filter — back into a single option string.

This widget is an editor for the *definition* of an option list, not a control
a shopper uses. The lists it maintains are what [select](select.md),
[radio](radio.md), and the other choice widgets consume.

## Examples

    [display type=option_format name=colors value="red=Red,green=Green*"]

renders a table (trimmed to the essential structure) whose first two rows carry
the existing options and whose remaining rows are blank for additions:

    <table cellpadding="0" cellspacing="0">
    <tr><th>...Value...</th><th colspan="2">...Label...</th></tr>
    <tr><td><input type="text" name="colors" value="red" size="8"></td>
        <td><input type="text" name="colors" value="Red" size="16"></td>
        <td><select name="colors"><option value="0">no<option value="1">default*</select></td></tr>
    <tr><td><input type="text" name="colors" value="green" size="8"></td>
        <td><input type="text" name="colors" value="Green" size="16"></td>
        <td><select name="colors"><option value="0">no<option value="1" SELECTED>default*</select></td></tr>
    ...blank rows...
    </table>

(The `green` row shows `default` selected because its label carried the
trailing `*`.)

## See also

- [option_format](../filters/option_format.md) filter — recombines the grid's
  fields into an option string
- [options](options.md) and [show](show.md) — read-only views of an option list
- [select](select.md) and [radio](radio.md) — widgets that consume the list

## Source

Defined in `code/Widget/option_format.widget`; implemented by
`Vend::Form::option_widget` (with `option_widget_box`) in `lib/Vend/Form.pm`.
