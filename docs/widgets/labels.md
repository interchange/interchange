# labels

A read-only widget that outputs the labels of every option in a list, joined by
a delimiter. Use it to show the human-readable side of a coded option set.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws it for
a field. Attribute values shown here are Interchange Tag Language (ITL) tag
attributes.

## Usage

    [display type=labels name=FIELD passed="a=Apple,b=Banana"]

To select it in the admin UI, set the field's `mv_metadata` `type` column to
`labels`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `passed` / `lookup` / `lookup_query` | (none) | Source of the option list |
| `delimiter` | `,` | String placed between labels |

This widget emits text only and submits nothing; it takes no form-control
options.

## Description

`labels` maps to `Vend::Form::show_labels`, which returns the second element
(the label) of every option in the resolved list, joined by `delimiter`. Where
an option has no explicit label the value stands in. Compare with
[options](options.md), which joins the *values*, and [show](show.md), which
joins `value=label` pairs.

## Examples

List every label:

    [display type=labels passed="a=Apple,b=Banana,c=Cherry"]

produces:

    Apple,Banana,Cherry

Use a custom delimiter:

    [display type=labels delimiter=" / " passed="sm=Small,md=Medium,lg=Large"]

produces:

    Small / Medium / Large

## See also

- [options](options.md) — the option *values*, joined
- [show](show.md) — `value=label` pairs, joined
- [display](display.md) — the label of the single selected value

## Source

Defined in `code/Widget/labels.widget`; maps to `Vend::Form::show_labels`
in `lib/Vend/Form.pm`.
