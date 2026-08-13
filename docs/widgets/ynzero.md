# ynzero

Renders a Yes/No control that stores **`1` for Yes and `0` for No**, defaulting
to No. Reach for it instead of [yesno](yesno.md) when the underlying column is
a numeric/`0`-or-`1` boolean and you need an explicit `0` on file for No rather
than an empty string.

## Usage

    [display type=ynzero name=FIELD]

By default the control is a dropdown (`select`). Pass `variant=radio` (or the
compound type `type="ynzero radio"`) to render radio buttons instead.

To choose this widget in the admin UI, set the `type` field of the field's
`mv_metadata` record (keyed `table::column`) to `ynzero`:

    code               type
    mytable::active    ynzero

`[display table=mytable column=active key=SKU]` then renders the stored value
with this widget.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | derived | HTML field name. Defaults to the column name under a meta lookup. |
| `value` | (looked up) | Current value; interpreted with the "is yes" test to decide which choice is preselected. |
| `variant` | `select` | Sub-widget: `select` (dropdown) or `radio`. |
| `yes_value` | `1` | Value stored for the Yes choice. |
| `no_value` | `0` | Value stored for the No choice (this is what distinguishes `ynzero` from `yesno`). |

## Description

`ynzero` is the [yesno](yesno.md) routine with one changed default: the widget
definition sets `no_value` to `0`, so the two-row option list is:

    0   ->  No
    1   ->  Yes

The current value runs through Interchange's `is_yes()` test. With no stored
value the value resolves to empty, which is neither `0` nor `1`, so no
`<option>` carries an explicit `SELECTED` marker and the browser shows the
first choice (No) — hence "default = No". The labels `Yes`/`No` come from
`errmsg()` and are localized through the locale database.

The rendered HTML is whatever the sub-widget produces: a `<select>` with two
`<option>` elements by default, or a pair of radio `<input>` elements when
`variant=radio`.

## Examples

Dropdown (default):

    [display type=ynzero name=example]

renders (No shows by default as the first option):

    <select name="example"><option value="0">No<option value="1">Yes</select>

Radio buttons:

    [display type=ynzero name=example variant=radio]

renders (wrapped here for readability):

    <input type="radio" name="example" value="0">&nbsp;No
    <input type="radio" name="example" value="1">&nbsp;Yes

## See also

- [yesno](yesno.md) — Yes stores `1`, No stores empty
- [noyes](noyes.md) — No stores `1`, Yes stores empty
- [select](select.md) and [radio](radio.md) — the sub-widgets it delegates to

## Source

Defined in `code/Widget/ynzero.widget` (which sets the `no_value` default to
`0`); implemented by `Vend::Form::yesno` in `lib/Vend/Form.pm`.
