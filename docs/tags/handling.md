# handling

Calculate the handling charge for the cart under a named handling mode.
Reach for it on basket, checkout, and receipt pages to show a handling line
separate from shipping.

## Syntax

    [handling]
    [handling mode]
    [handling mode=insurance]

Standalone tag (no end tag). By default it returns an unformatted numeric
amount; the result is not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute  | Default | Description |
|------------|---------|-------------|
| `mode`     | `mv_handling` value field | Handling mode(s) to total; multiple modes may be separated by whitespace, commas, or nulls. |
| `cart`     | current cart | Name of the cart to charge. |
| `table`    | shipping table | Shipping/handling lookup table to read. |
| `default`  | `0` | When true, fall back to a default charge if the named mode yields nothing. |
| `noformat` | `1` | Return the raw number; set false to currency-format the result. |

Positional order: `mode`.

Aliases: `name` and `modes` for `mode`; `carts` for `cart`; `tables` for
`table`.

Because the tag declares `addAttr`, any other attribute is forwarded to the
shipping routine as an option.

## Description

`[handling]` shares Interchange's shipping engine: it calls the same routine
as [shipping](shipping.md) but forces the `handling` flag, so charges are
looked up as handling rather than shipping. When no `mode` is supplied, the
tag uses the customer's `mv_handling` value field.

Handling modes are defined the same way shipping modes are — in the
`shipping` table or `shipping.asc` source — and the charge is computed from
the cart's weight, quantity, or subtotal according to that mode's formula.
Multiple modes given at once are summed.

Unlike [salestax](salestax.md) and [subtotal](subtotal.md), `[handling]`
returns an unformatted number by default (it is invoked internally with
`noformat` and `convert` set), so it composes cleanly into calculations. Pass
`noformat=0` to get a locale-formatted currency string instead.

## Examples

Total the handling for the current cart using the customer's selected
handling mode:

    Handling: [currency][handling][/currency]

Charge a specific handling mode:

    [handling mode=insurance]

Sum two handling modes and format the result:

    [handling mode="insurance giftwrap" noformat=0]

## Notes

Handling modes must be configured in the shipping data (the `shipping` table
or `shipping.asc`). With no matching mode and no `default`, the tag returns
`0`.

## See also

- [shipping](shipping.md)
- [shipping-desc](shipping-desc.md)
- [salestax](salestax.md)
- [levies](levies.md)
- [currency](currency.md)
- Concepts: [shipping](../guides/shipping.md)

## Source

Defined in `code/SystemTag/handling.coretag`. Implemented by
`Vend::Ship::tag_handling` (aliased as `Vend::Interpolate::tag_handling`),
which delegates to `Vend::Ship::tag_shipping`.
