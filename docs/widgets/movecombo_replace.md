# movecombo_replace

Like [movecombo](movecombo.md), but choosing an option *replaces* the text
box's contents instead of appending to them — so exactly one value is collected.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws it for
a field. Attribute values shown here are Interchange Tag Language (ITL) tag
attributes.

## Usage

    [display type=movecombo_replace name=FIELD passed="a=Apple,b=Banana"]

To select it in the admin UI, set the field's `mv_metadata` `type` column to
`movecombo_replace`.

## Options

Identical to [movecombo](movecombo.md) — `name`, `value`, `passed`,
`rows`/`height`, `cols`/`width`, `reverse`, `o_template` — except that the
`replace` behavior is always on.

## Description

`movecombo_replace` has no routine of its own. When Interchange resolves the
widget type, `parse_type` (in `lib/Vend/Form.pm`) recognizes the `movecombo`
stem, sets the internal type to `movecombo`, and — because the name contains
`replace` — sets the `replace` flag. `Vend::Form::movecombo` then passes
`only => 1` as the fourth argument to the client-side `addItem()` function, so
the selected option overwrites the collector box rather than being appended.
Everything else matches [movecombo](movecombo.md), including the requirement
that an `addItem` JavaScript function be available on the page.

## Examples

Pick a single home region into a text box:

    [display type=movecombo_replace name=region passed="us=United States,ca=Canada,uk=United Kingdom"]

Rendered HTML (trimmed — note the trailing `1` that enables replace):

    <select name="Xregion" onChange="addItem(this.form['Xregion'],this.form['region'],0,1)">
    <option value="us">United States</option>
    <option value="ca">Canada</option>
    <option value="uk">United Kingdom</option>
    </select>
    <input type="text" size="16" name="region" value="">

## See also

- [movecombo](movecombo.md) — the multi-value base widget
- [select](select.md) — a plain single-choice dropdown

## Source

Defined in `code/Widget/movecombo.widget` (alongside
[movecombo](movecombo.md)). The `replace` behavior is applied by `parse_type`
and carried out by `Vend::Form::movecombo` in `lib/Vend/Form.pm`.
