# combo

Renders a dropdown [select](select.md) together with a free-text input, so a
form can either pick an existing option or type a new value. It is the widget
behind the image and key pickers in the admin UI.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws the
control for a field. Attribute values shown here are Interchange Tag Language
(ITL) tag attributes.

## Usage

    [display type=combo name=FIELD passed="a=Apple,b=Banana"]

To select it in the admin UI, set the field's `mv_metadata` `type` column to
`combo`:

| code (`table::column`) | type | options |
|------------------------|------|---------|
| `products::category`   | combo | `books=Books,music=Music` |

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | (required) | Form variable for both the select and the text box |
| `value` | (empty) | Current value; a matching option is pre-selected |
| `passed` / `lookup` / `lookup_query` | (none) | Source of the option list |
| `cols` | (none) | Width of the free-text input |
| `textarea` | off | Use a textarea instead of a one-line text input |
| `rows` | (none) | With `textarea`, the number of rows |
| `reverse` | off | Put the text box before the select instead of after |
| `filter` | (none) | Post-filter (commonly `nullselect`, see Description) |

## Description

`combo` maps to `Vend::Form::combo`. It builds an ordinary dropdown with
`Vend::Form::dropdown` and adds a text input that carries the *same* form
`name`. By default the text input is prepended (drawn before the select via the
widget's `prepend`); with `reverse` it is appended after. With `textarea` the
free-text control becomes a `<textarea>` sized by `rows`/`cols`.

Because the select and the text box share a name, a form that leaves the text
box empty still submits an empty value for it. Callers therefore usually attach
the `nullselect` filter, which discards the empty half so only the chosen or
typed value remains. The [gpg_keys](gpg_keys.md) and [imagedir](imagedir.md)
widgets are thin wrappers that build their option list and then render it as a
`combo` with `nullselect`.

The option list is resolved exactly as for other list widgets: from `passed`,
from a `lookup`/`lookup_query`, or from the field's column data in the table
editor.

## Examples

Pick an existing category or type a new one:

    [display type=combo name=category passed="books=Books,music=Music" value="books"]

Rendered HTML (trimmed):

    <input type="text" name="category" size="" value="">
    <select name="category">
    <option value="books" SELECTED>Books</option>
    <option value="music">Music</option>
    </select>

Text box first, wider, discarding the empty half on submit:

    [display type=combo name=category reverse=1 cols=30 filter=nullselect
             passed="books=Books,music=Music"]

## See also

- [select](select.md) — plain dropdown without the add-value box
- [movecombo](movecombo.md) — move options into a text box, keeping the list
- [gpg_keys](gpg_keys.md), [imagedir](imagedir.md) — widgets built on `combo`
- The `nullselect` filter (`../filters/`)

## Source

Defined in `code/Widget/combo.widget`; maps to `Vend::Form::combo` in
`lib/Vend/Form.pm`.
