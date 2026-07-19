# display

A read-only widget that shows the *label* of the currently selected option
rather than an editable control. Use it to display a coded value's
human-readable text in a form or listing.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) tag (the
tag and this widget share a name) or the [widget](../admin-tags/widget.md) tag,
or by naming it in an `mv_metadata` record so the admin
[table_editor](../admin-tags/table_editor.md) draws it for a field. Attribute
values shown here are Interchange Tag Language (ITL) tag attributes.

## Usage

    [display type=display name=FIELD value="VALUE" passed="a=Apple,b=Banana"]

To select it in the admin UI, set the field's `mv_metadata` `type` column to
`display`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `value` | (empty) | The current value whose label is shown |
| `default` | (empty) | Value used when `value` is empty |
| `passed` / `lookup` / `lookup_query` | (none) | Source of the value/label option list |

This widget outputs text only, so it takes no form-control options; `name` is
accepted but nothing is submitted.

## Description

`display` maps to `Vend::Form::current_label`. It walks the resolved option
list looking for the entry whose value equals the widget's current value and
returns that entry's label (or the raw value if the entry has no label). A
label or value ending in `*` marks the list default, which is returned when the
current value matches nothing. If the list is empty or no match and no default
is found, the raw value is returned unchanged.

Contrast this with [labels](labels.md), which returns the labels of *all*
options, and with [value](value.md), which shows the stored value itself.

## Examples

Show the label for a stored code:

    [display type=display name=size value="lg" passed="sm=Small,md=Medium,lg=Large"]

produces:

    Large

When the value matches no option, the default (marked `*`) is shown:

    [display type=display value="" passed="sm=Small,md=Medium*,lg=Large"]

produces:

    Medium

If there is no match and no default, the value passes through:

    [display type=display value="xl" passed="sm=Small,lg=Large"]

produces:

    xl

## See also

- [labels](labels.md) — labels of every option, joined
- [value](value.md) — the stored value itself
- [show](show.md), [options](options.md) — other read-only list widgets
- [display](../admin-tags/display.md) tag — renders any widget

## Source

Defined in `code/Widget/display.widget`; maps to `Vend::Form::current_label`
in `lib/Vend/Form.pm`.
