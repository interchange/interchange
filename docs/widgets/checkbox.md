# checkbox

Renders one HTML checkbox per option, letting a form select one value or many
from a list. It is Interchange's standard multi-value box control.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws the
control for a field. Attribute values shown here are Interchange Tag Language
(ITL) tag attributes.

## Usage

    [display type=checkbox name=FIELD passed="val1=Label 1,val2=Label 2"]

To select it in the admin UI, set the `type` column of the field's
`mv_metadata` record to `checkbox`:

| code (`table::column`) | type | options |
|------------------------|------|---------|
| `products::features`   | checkbox | `gift=Gift wrap,rush=Rush ship` |

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | (required) | Form variable that receives the checked values |
| `value` | (empty) | Current value(s); options whose value matches are checked |
| `passed` | (none) | Inline option list, `value=Label` pairs |
| `options` | (none) | Alias source for the option list (see Description) |
| `lookup` / `lookup_query` | (none) | Build options from a database column or query |
| `left` / `right` | off | Lay checkboxes out in a table with the label left or right of the box |
| `breakmod` | (none) | Start a new table row every N checkboxes |
| `contains` | off | Match the value anywhere, not only on word boundaries |
| `id` | (none) | Base id; each box gets `id`+value and a `<label>` |

This widget is declared `Multiple`, so a submitted set of checked boxes is
stored as a multi-valued field.

## Description

`checkbox` maps to `Vend::Form::box`. The option list is resolved the same way
for every list widget: from `passed`, from a `lookup`/`lookup_query` against a
table, or (in the table editor) from the field's own column data. Each option
is a `value=Label` pair; a trailing `*` on a label or value marks it selected
by default.

For each option the widget emits an `<input type="checkbox">` whose `value` is
the option value and whose `name` is the field name. A box is checked when the
widget's current value contains that option value (matched on word boundaries
unless `contains` is set). With `left` or `right` the boxes are wrapped in a
`<table>` with the label on the requested side; otherwise each box is followed
by its label and rendered inline.

See [check_nbsp](check_nbsp.md) for the variant that renders label spaces as
non-breaking spaces.

## Examples

A two-option checkbox group:

    [display type=checkbox name=features passed="gift=Gift wrap,rush=Rush ship" value="gift"]

Rendered HTML (trimmed):

    <input type="checkbox" name="features" value="gift" checked>&nbsp;Gift wrap
    <input type="checkbox" name="features" value="rush">&nbsp;Rush ship

A single yes/no checkbox (one option, blank label):

    [display type=checkbox name=active passed="1= " value="1"]

produces:

    <input type="checkbox" name="active" value="1" checked>&nbsp;

Lay the boxes out with labels to the right, two per row:

    [display type=checkbox name=features right=1 breakmod=2
             passed="gift=Gift wrap,rush=Rush ship,card=Gift card,box=Gift box"]

## See also

- [check_nbsp](check_nbsp.md) — same widget, `&nbsp;` for label spaces
- [radio](radio.md) — single-choice sibling using radio buttons
- [multiple](multiple.md), [select](select.md) — dropdown list controls
- [display](../admin-tags/display.md), [widget](../admin-tags/widget.md)

## Source

Defined in `code/Widget/checkbox.widget` (the same file defines
[check_nbsp](check_nbsp.md)). The `checkbox` entry maps to
`Vend::Form::box` in `lib/Vend/Form.pm`.
