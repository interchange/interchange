# state_select

Renders the placeholder for a dynamic state/province control that a companion
[country_select](country_select.md) widget fills in with the right list (or a
free-text box) for the chosen country.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws the
control for a field. Attribute values shown here are Interchange Tag Language
(ITL) tag attributes.

## Usage

    [display type=state_select name=state value="[value state]"]

It only works alongside a [country_select](country_select.md) on the same
form:

    [display type=country_select name=country value="[value country]"]

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | (required) | Form variable that holds the selected state |
| `value` | (empty) | Current state value |
| `state_element` | `state_widget_container` | CSS id of the `<span>` the country widget targets |

If `name` begins with a single-letter prefix like `b_`, the default
`state_element` picks up that prefix (`b_state_widget_container`) so a billing
and shipping block on one page stay independent. In the admin UI this is the
only extra field the widget exposes ("State element ID").

## Description

`state_select` renders two things: a hidden input carrying the current state
value (so the state is submitted even before any JavaScript runs), and an empty
`<span>` whose id matches the `state_element`. That span is the target the
[country_select](country_select.md) widget rewrites on load and on every
country change — inserting a `<select>` of states, a text input, or a
"No state required" note as appropriate. The state list itself comes from the
`state` table and is emitted by `country_select`, not by this widget; on its
own `state_select` produces no list.

The hidden field is created by the shared `Vend::Form::display` dispatcher with
`type => 'hidden'`.

## Examples

    [display type=state_select name=state value="[value state]"]

Rendered HTML:

    <input type="hidden" name="state" value="CA"><span id="state_widget_container"></span>

With a billing prefix, the container id follows the name prefix:

    [display type=state_select name=b_state value="[value b_state]"]

produces:

    <input type="hidden" name="b_state" value=""><span id="b_state_widget_container"></span>

## See also

- [country_select](country_select.md) — the required companion that populates
  this widget
- [cart-and-checkout](../guides/cart-and-checkout.md)

## Source

Defined in `code/Widget/country_select.widget` (alongside
[country_select](country_select.md)). The routine is inline and calls
`Vend::Form::display` in `lib/Vend/Form.pm`.
