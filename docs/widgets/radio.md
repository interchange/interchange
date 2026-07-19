# radio

Renders a group of radio-button `<input>` elements — one per choice — from a
list of value/label pairs. Reach for it instead of [select](select.md) when the
choice set is short and you want every option visible at once.

## Usage

    [display type=radio name=FIELD passed="v1=Label 1,v2=Label 2"]

The choices come from the same sources as [select](select.md) (a `passed`
string, a database `lookup`/`lookup_query`, or a meta record's `options`
field). To choose this widget in the admin UI, set the `type` field of the
field's `mv_metadata` record (keyed `table::column`) to `radio` and put the
choices in the `options` field:

    code             type     options
    mytable::size    radio    S=Small,M=Medium,L=Large

`[display table=mytable column=size key=SKU]` then renders the radio group.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | derived | HTML field name shared by every button in the group. |
| `value` | (looked up) | Current value; the matching button gets `checked`. |
| `passed` | none | Option string, e.g. `S=Small,M=Medium`. |
| `lookup` / `lookup_query` | none | Build the choices from the database (see [select](select.md)). |
| `breakmod` | none | With `left`/`right`, lay the buttons out in an HTML table this many columns wide. |
| `left` | off | Put each label in a table cell to the left of its button. |
| `right` | off | Put each label to the right of its button. |
| `contains` | off | Match the current value as a substring rather than a whole word (for multi-value fields). |
| `id` | none | Base id; each button gets `id`/`<label for>` derived from it plus the value. |
| `extra` | none | Extra attributes inserted into each `<input>` tag. |

## Description

`radio` (the `box` routine, shared with `checkbox`) emits one
`<input type="radio">` per choice. Choices are `value=label` pairs, split the
same way as [select](select.md); a bare value is its own label, a trailing `*`
marks a default, and `~~Group~~` values insert a bold group header.

By default each button is followed by `&nbsp;` and its label, and the buttons
run together with no separator, so you normally place them inside your own
markup. The `left`/`right` options wrap the group in a `<table>` (using
`breakmod` for the column count); the [radio_nbsp](radio_nbsp.md) widget is the
same control with spaces in labels converted to `&nbsp;`.

The current `value` is matched against each option value (as a whole word, or
as a substring when `contains` is set) and the matching button receives
`checked`.

## Examples

A minimal radio group:

    [display type=radio name=size passed="S=Small,M=Medium,L=Large"]

renders (the buttons concatenate with no separator; wrapped here for
readability):

    <input type="radio" name="size" value="S">&nbsp;Small
    <input type="radio" name="size" value="M">&nbsp;Medium
    <input type="radio" name="size" value="L">&nbsp;Large

With a current value, that button is checked:

    [display type=radio name=size value=M passed="S=Small,M=Medium,L=Large"]

renders (middle button marked):

    <input type="radio" name="size" value="S">&nbsp;Small
    <input type="radio" name="size" value="M" checked>&nbsp;Medium
    <input type="radio" name="size" value="L">&nbsp;Large

## See also

- [radio_nbsp](radio_nbsp.md) — radio group with `&nbsp;`-protected labels
- [checkbox](checkbox.md) — the multi-select sibling built by the same routine
- [select](select.md) — the same choices as a dropdown
- [forms](../guides/forms.md) — building and processing forms

## Source

Defined in `code/Widget/radio.widget` (which also defines `radio_nbsp`);
implemented by `Vend::Form::box` in `lib/Vend/Form.pm`.
