# country_select

Renders a country dropdown built from the `country` table and emits the
JavaScript that drives a companion [state_select](state_select.md) widget, so
the state control updates itself when the shopper changes country.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws the
control for a field. Attribute values shown here are Interchange Tag Language
(ITL) tag attributes.

## Usage

    [display type=country_select name=country value="[value country]"]

Pair it with a [state_select](state_select.md) elsewhere on the same form:

    [display type=state_select name=state value="[value state]"]

To select it in the admin UI, set the field's `mv_metadata` `type` column to
`country_select`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | `country` | Form variable for the selected country code |
| `value` | (empty) | Pre-selected country code |
| `country_table` | `country` | Table holding the country list |
| `country_sort` | `sorder,name` (or `name` with `no_region`) | Sort order for countries |
| `no_region` | off | Omit the region `<optgroup>` headings |
| `only_with_shipping` | off | Only list countries whose `shipmodes` is set |
| `state_table` | `state` | Table the companion state widget reads |
| `state_sort` | `country,name` | Sort order for states |
| `state_var` / `state_variable` | `state` | Form variable the state widget writes |
| `state_element` | `state_widget_container` | CSS id of the `<span>` the state widget fills |
| `state_size` / `cols` / `width` | `16` | Width of the state text input when a country has free-form states |
| `state_class` | (none) | CSS class applied to the state control |
| `state_style` | `font-style: italic; font-size: smaller` | Style for the "No state required" note |
| `state_js` | (none) | Extra JavaScript run on state change |
| `country_js` | (none) | Extra JavaScript run on country change |
| `form_name` | (auto-detected) | Name of the enclosing `<form>` |

When `name` begins with a single-letter prefix like `b_` (as in
`b_country` for a billing address), that prefix is carried over to the default
state variable and container id (`b_state`, `b_state_widget_container`), so a
billing and a shipping block on one page do not collide.

## Description

`country_select` queries the `country` table, sorts it, and — unless
`no_region` is set — inserts an `<optgroup>` for each `region` value. With
`only_with_shipping` it drops countries that have no `shipmodes`. Countries
flagged `no_state` are recorded so the state control can show "No state
required" for them.

The widget also builds JavaScript arrays of the states for every country (from
the `state` table) and a `..._widget_adjust_state()` function, wired to the
select's `onLoad`/`onChange`. When the country changes, that function rewrites
the innerHTML of the `<span id="state_widget_container">` supplied by
[state_select](state_select.md): a `<select>` of states for countries that have
them, a plain text input for countries that do not, or the "No state required"
note for `no_state` countries. The country `<select>` itself is produced by the
shared `Vend::Form::display` dispatcher with `type => 'select'`.

The strap demo's checkout address blocks use this widget; see
`dist/strap/include/checkout/shipping_address`.

## Examples

Minimal shipping-country selector defaulting to the value on file:

    [display type=country_select name=country value="[value country]"]

Rendered HTML (heavily trimmed — the surrounding `<script>` blocks are
omitted):

    <select name="country" onLoad="country_widget_adjust_state(this)"
            onChange="country_widget_adjust_state(this)">
    <optgroup label="Asia">
    <option value="AF">Afghanistan</option>
    ...
    </optgroup>
    <optgroup label="Europe">
    ...
    </optgroup>
    </select>
    <span id="state_widget_container"></span>

A billing-address selector with no region groups and a tax hook, matching the
strap checkout:

    [display type=country_select name=country id=country
             value="[either][value country][or][value mv_default_country][/either]"
             no_region=1 state_js="check_tax(this.form)"]

## See also

- [state_select](state_select.md) — the required companion widget
- [select](select.md) — the plain dropdown this builds on
- [cart-and-checkout](../guides/cart-and-checkout.md),
  [internationalization](../guides/internationalization.md)

## Source

Defined in `code/Widget/country_select.widget` (the same file defines
[state_select](state_select.md)). The routine is inline in that file and
finishes by calling `Vend::Form::display` in `lib/Vend/Form.pm`.
