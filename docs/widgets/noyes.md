# noyes

Renders a two-choice No/Yes control whose sense is reversed from
[yesno](yesno.md): choosing **No** stores `1` (true) and choosing **Yes**
stores an empty (false) value. Reach for it when the stored column means
"suppress" or "disable" — where the affirmative answer is the empty default.

## Usage

    [display type=noyes name=FIELD]

By default the control is a dropdown (`select`). Pass `variant=radio` (or the
compound type `type="noyes radio"`) to render radio buttons instead.

To choose this widget in the admin UI, set the `type` field of the field's
`mv_metadata` record (keyed `table::column`) to `noyes`:

    code            type
    mytable::hide   noyes

`[display table=mytable column=hide key=SKU]` then renders the stored value
with this widget.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | derived | HTML field name. When called from a meta lookup it defaults to the column name. |
| `value` | (looked up) | Current value; interpreted with Interchange's "is no" test to decide which choice is preselected. |
| `variant` | `select` | Sub-widget used to render the two choices: `select` (dropdown) or `radio`. |

The No/Yes labels are not configurable through options here; they come from the
locale (see Description).

## Description

`noyes` builds a fixed two-row option list and hands it to a sub-widget:

    1   ->  No
    (empty) ->  Yes

The current value is passed through Interchange's `is_no()` test, so any value
beginning with `n`, `f`, `0`, or an undefined value counts as "No" and
preselects the `1`/No choice — this is why the widget's help reads "Default is
1 for No". The two labels `No` and `Yes` are produced with `errmsg()`, so
adding translations to the locale database localizes them automatically.

The rendered HTML is whatever the sub-widget produces: an ordinary
`<select>` with two `<option>` elements by default, or a pair of radio
`<input>` elements when `variant=radio`.

## Examples

Dropdown (default):

    [display type=noyes name=example]

renders (No is preselected because the value is empty):

    <select name="example"><option value="1" SELECTED>No<option value="">Yes</select>

Radio buttons:

    [display type=noyes name=example variant=radio]

renders (concatenated inline; wrapped here for readability):

    <input type="radio" name="example" value="1">&nbsp;No
    <input type="radio" name="example" value="">&nbsp;Yes

## See also

- [yesno](yesno.md) — same widget with the sense reversed (Yes stores `1`)
- [ynzero](ynzero.md) — Yes/No where No stores `0` rather than empty
- [select](select.md) and [radio](radio.md) — the sub-widgets it delegates to
- [forms](../guides/forms.md) — building and processing forms

## Source

Defined in `code/Widget/noyes.widget`; implemented by
`Vend::Form::noyes` in `lib/Vend/Form.pm`.
