# yesno

Renders a two-choice Yes/No control: choosing **Yes** stores `1` (true) and
choosing **No** stores an empty (false) value. Reach for it whenever a column
holds a boolean flag and you want a friendly, locale-aware Yes/No control
instead of a raw text box.

## Usage

    [display type=yesno name=FIELD]

By default the control is a dropdown (`select`). Pass `variant=radio` (or the
compound type `type="yesno radio"`) to render radio buttons instead.

To choose this widget in the admin UI, set the `type` field of the field's
`mv_metadata` record (keyed `table::column`) to `yesno`. The strap demo does
exactly this for the affiliate "active" flag:

    code                type
    affiliate::active   yesno

`[display table=affiliate column=active key=CODE]` then renders the stored
value as a Yes/No control.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | derived | HTML field name. Defaults to the column name under a meta lookup. |
| `value` | (looked up) | Current value; interpreted with the "is yes" test to decide which choice is preselected. |
| `variant` | `select` | Sub-widget: `select` (dropdown) or `radio`. |
| `yes_value` | `1` | Value stored for the Yes choice. |
| `no_value` | (empty) | Value stored for the No choice. |
| `yes_title` | `Yes` | Label for the Yes choice (localized via the locale database). |
| `no_title` | `No` | Label for the No choice. |

## Description

`yesno` builds a fixed two-row option list and hands it to a sub-widget:

    (empty) ->  No
    1       ->  Yes

The current value is passed through Interchange's `is_yes()` test, so any value
beginning with `y`, `t`, or `1` counts as "Yes". The labels default to
`errmsg('Yes')` and `errmsg('No')`, so translations added to the locale
database localize them automatically. Supply `yes_value`/`no_value` to change
the stored values and `yes_title`/`no_title` to change the labels without
touching the locale.

The rendered HTML is whatever the sub-widget produces: an ordinary `<select>`
with two `<option>` elements by default, or a pair of radio `<input>` elements
when `variant=radio`.

## Examples

Dropdown (default):

    [display type=yesno name=example]

renders (No is preselected because the empty value matches `no_value`):

    <select name="example"><option value="" SELECTED>No<option value="1">Yes</select>

Radio buttons:

    [display type=yesno name=example variant=radio]

renders (wrapped here for readability):

    <input type="radio" name="example" value="">&nbsp;No
    <input type="radio" name="example" value="1">&nbsp;Yes

A more flexible Yes/No with your own values and labels can also be built
directly with [select](select.md):

    [display type=select name=example passed="=No,1=Yes"]

## Notes

The historic reference states that only the compound form `type="yesno radio"`
selects the radio variant through Interchange Tag Language (ITL). In the
current code that restriction applies to the [widget](../admin-tags/widget.md)
tag, which does not forward a separate `variant` attribute; the
[display](../admin-tags/display.md) tag *does* forward `variant`, so
`variant=radio` works there. The compound `type="yesno radio"` form works with
both tags and is the portable choice.

## See also

- [noyes](noyes.md) — the same widget with the sense reversed (No stores `1`)
- [ynzero](ynzero.md) — Yes/No where No stores `0` rather than empty
- [select](select.md) and [radio](radio.md) — the sub-widgets it delegates to
- [forms](../guides/forms.md) — building and processing forms

## Source

Defined in `code/Widget/yesno.widget`; implemented by
`Vend::Form::yesno` in `lib/Vend/Form.pm`.
