# radio_nbsp

Renders a group of radio buttons exactly like [radio](radio.md), but with each
label's spaces converted to non-breaking spaces (`&nbsp;`) so multi-word labels
stay on one line.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws the
control for a field. Attribute values shown here are Interchange Tag Language
(ITL) tag attributes.

## Usage

    [display type=radio_nbsp name=FIELD passed="val1=Label 1,val2=Label 2"]

To select it in the admin UI, set the field's `mv_metadata` `type` column to
`radio_nbsp`:

| code (`table::column`) | type | options |
|------------------------|------|---------|
| `mytable::ship`        | radio_nbsp | `ground=Ground shipping,air=Air shipping` |

## Options

Identical to [radio](radio.md) — `name`, `value`, `passed`,
`lookup`/`lookup_query`, `left`/`right`, `breakmod`, `contains`, `id`, `extra`.
The choices come from the same sources ([select](select.md)-style `passed`
string, a database lookup, or a meta record's `options` field).

## Description

`radio_nbsp` has no routine of its own. When Interchange resolves the widget
type it runs `parse_type` (in `lib/Vend/Form.pm`), which recognizes any type
matching `radio`, rewrites it to the internal `radio` type, and — because the
name contains `nbsp` — sets the `nbsp` flag. Rendering is then handled by
`Vend::Form::box`, which uses the `boxnbsp` template: label spaces become
`&nbsp;`, and each button is padded with two trailing non-breaking spaces. The
standalone `CodeDef radio_nbsp` entry exists so the admin widget picker lists it
as "Radio box (nbsp)".

Everything else — how options are resolved, how the current value checks a
button, `~~Group~~` headers and trailing-`*` defaults — matches
[radio](radio.md).

## Examples

    [display type=radio_nbsp name=ship passed="ground=Ground shipping,air=Air shipping"]

Rendered HTML (trimmed; note the escaped label spaces and the two trailing
`&nbsp;` that separate the buttons):

    <input type="radio" name="ship" value="ground">&nbsp;Ground&nbsp;shipping&nbsp;&nbsp;
    <input type="radio" name="ship" value="air">&nbsp;Air&nbsp;shipping&nbsp;&nbsp;

With a current value, that button is checked:

    [display type=radio_nbsp name=ship value=air passed="ground=Ground shipping,air=Air shipping"]

renders (second button marked):

    <input type="radio" name="ship" value="ground">&nbsp;Ground&nbsp;shipping&nbsp;&nbsp;
    <input type="radio" name="ship" value="air" checked>&nbsp;Air&nbsp;shipping&nbsp;&nbsp;

## See also

- [radio](radio.md) — the base widget this one specializes
- [check_nbsp](check_nbsp.md) — the checkbox equivalent, rewritten the same way
- [checkbox](checkbox.md), [select](select.md) — other ways to present choices
- [display](../admin-tags/display.md), [widget](../admin-tags/widget.md)
- [forms](../guides/forms.md) — building and processing forms

## Source

Defined in `code/Widget/radio.widget` (alongside [radio](radio.md)). The `nbsp`
behavior is applied by `parse_type` and rendered by `Vend::Form::box` (via the
`boxnbsp` template) in `lib/Vend/Form.pm`.
