# shipping

Calculate the shipping cost for a shipping mode, or produce a list/widget of
the available modes. With no attributes it returns the formatted shipping cost
for the current cart under the customer's selected mode.

## Syntax

    [shipping]
    [shipping mode]
    [shipping mode=UPSG noformat=1]
    [shipping possible=1]
    [shipping label=1 widget=select]

Standalone tag (no end tag). By default the result is a currency-formatted
string; it is not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute        | Default | Description |
|------------------|---------|-------------|
| `mode`           | `mv_shipmode` value, or `default` | Shipping mode(s) to price; multiple modes may be given whitespace- or comma-separated. |
| `noformat`       | `0`     | Return the raw number instead of a currency-formatted string. |
| `handling`       | `0`     | Price the handling charge (from `mv_handling`) rather than shipping. |
| `possible`       | `0`     | Return the list of currently valid shipping modes instead of a cost. |
| `resolve`        | `0`     | Update `mv_shipmode` to a valid mode if the current one is not valid. |
| `check_validity` | `0`     | Test whether the current `mv_shipmode` is still valid. |
| `label`          | `0`     | Produce labeled `mode=description` output for each mode (for building menus). |
| `widget`         | none    | Render the modes as a form widget of this type (for example `select`). |
| `default`        | `0`     | Fall back to the `mv_shipmode` cost if the given mode yields nothing. |
| `add`            | `0`     | Re-read the shipping definitions before calculating. |
| `file`           | none    | Read shipping definitions from this file before calculating. |
| `reset_modes`    | `0`     | Clear the accumulated shipping lines before calculating. |
| `hide`           | `0`     | Perform the calculation but return nothing. |

Positional order: `mode`.

Aliases: `name`, `modes` for `mode`; `table`/`tables` for the shipping table;
`cart`/`carts` for the cart to price.

The tag declares `addAttr`, so further options — including `country_var` and
`state_var` (the value fields naming the destination, default `country` and
`state`), `free` (text substituted for a zero cost), and `output_options` — are
read from the attribute list and passed through to the shipping engine.

## Description

`[shipping]` maps to `Vend::Ship::tag_shipping`. Its behavior depends on which
attributes you pass:

- **Cost (default).** With no mode-listing options it sums the shipping cost of
  the given mode(s) for the current cart, rounds it, and formats it as currency
  (unless `noformat`). If a fixed shipping (or handling) amount has been
  assigned into the session, that value is used instead of a recalculation.
- **Handling.** `handling=1` prices the handling charge, taken from the
  `mv_handling` value field, instead of shipping.
- **Mode discovery.** `possible=1` returns the modes currently valid for the
  destination; `check_validity=1` and `resolve=1` test and, respectively, fix
  the customer's selected `mv_shipmode`.
- **Menus and widgets.** `label=1` emits `mode=description` pairs suitable for
  building an option list, and `widget=TYPE` renders the modes directly as a
  form control named `mv_shipmode`.

Which modes are valid depends on the destination, read from the value fields
named by `country_var` and `state_var`, so those form values must be set for
destination-sensitive rates to resolve correctly. Mode descriptions and other
per-mode fields are available through [shipping-desc](shipping-desc.md).

## Examples

Show the shipping cost for the current cart and selected mode:

    Shipping: [shipping]

Get the raw number for a specific mode, for use in a calculation:

    [tmp ship_raw][shipping mode=UPSG noformat=1][/tmp]

Build a select menu of the available modes with their labels and costs:

    <select name="mv_shipmode">
    [loop list="[shipping possible=1]"]
      <option value="[loop-code]">
        [shipping-desc mode="[loop-code]"] — [shipping mode="[loop-code]"]
      </option>
    [/loop]
    </select>

Render the same menu directly as a widget:

    [shipping label=1 widget=select]

## Notes

`[shipping possible=1]` and the `check_validity`/`resolve` options let a
checkout page keep the selected mode consistent as the destination changes.

## See also

- [shipping-desc](shipping-desc.md), [salestax](salestax.md),
  [assign](assign.md)
- [loop](loop.md), [currency](currency.md)
- Concepts: [shipping](../guides/shipping.md),
  [cart-and-checkout](../guides/cart-and-checkout.md)

## Source

Defined in `code/SystemTag/shipping.coretag`. Implemented by
`Vend::Ship::tag_shipping`.
