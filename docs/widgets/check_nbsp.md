# check_nbsp

Renders a group of HTML checkboxes exactly like [checkbox](checkbox.md), but
with each label's spaces converted to non-breaking spaces (`&nbsp;`) so
multi-word labels stay on one line.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws the
control for a field. Attribute values shown here are Interchange Tag Language
(ITL) tag attributes.

## Usage

    [display type=check_nbsp name=FIELD passed="val1=Label 1,val2=Label 2"]

To select it in the admin UI, set the field's `mv_metadata` `type` column to
`check_nbsp`:

| code (`table::column`) | type | options |
|------------------------|------|---------|
| `products::features`   | check_nbsp | `gift=Gift wrap,rush=Rush ship` |

## Options

Identical to [checkbox](checkbox.md) — `name`, `value`, `passed`, `options`,
`lookup`/`lookup_query`, `left`/`right`, `breakmod`, `contains`, `id`. Like
`checkbox`, this widget is declared `Multiple`.

## Description

`check_nbsp` has no routine of its own. When Interchange resolves the widget
type it runs `parse_type` (in `lib/Vend/Form.pm`), which recognizes any type
matching `check`, rewrites it to the internal `checkbox` type, and — because
the name contains `nbsp` — sets the `nbsp` flag. Rendering is then handled by
`Vend::Form::box`, which uses the `boxnbsp` template: label spaces become
`&nbsp;`, and each box is padded with trailing non-breaking spaces. The
standalone `CodeDef check_nbsp` entry exists so the admin widget picker lists
it as "Checkbox (nbsp)".

Everything else — how options are resolved, how the current value checks boxes,
multi-value storage — matches [checkbox](checkbox.md).

## Examples

    [display type=check_nbsp name=features passed="gift=Gift wrap,rush=Rush ship" value="gift"]

Rendered HTML (trimmed; note the escaped label spaces):

    <input type="checkbox" name="features" value="gift" checked>&nbsp;Gift&nbsp;wrap&nbsp;&nbsp;
    <input type="checkbox" name="features" value="rush">&nbsp;Rush&nbsp;ship&nbsp;&nbsp;

## See also

- [checkbox](checkbox.md) — the base widget this one specializes
- [radio_nbsp](radio.md) — the radio-button equivalent (documented with
  [radio](radio.md))
- [display](../admin-tags/display.md), [widget](../admin-tags/widget.md)

## Source

Defined in `code/Widget/checkbox.widget` (alongside
[checkbox](checkbox.md)). The `nbsp` behavior is applied by `parse_type` and
rendered by `Vend::Form::box` in `lib/Vend/Form.pm`.
