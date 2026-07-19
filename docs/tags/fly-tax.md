# fly-tax

Compute sales tax "on the fly" from the catalog's `TAXRATE` variable rather
than from a database table. Reach for it when you want simple per-region tax
rates configured with a handful of Variable settings instead of a
`SalesTax` lookup table.

## Syntax

    [fly-tax]
    [fly-tax area]
    [fly-tax area=CA]

Standalone tag (no end tag). The result is a raw unformatted number (the tax
amount), not a currency-formatted string, and it is not reparsed as
Interchange Tag Language (ITL).

## Attributes

| Attribute        | Default | Description |
|------------------|---------|-------------|
| `area`           | derived from `SalesTax` value fields | The tax region key to look up in the `TAXRATE` variable. |
| `cart`           | current cart | Name of the cart whose contents are taxed. |
| `discount_space` | current | Discount namespace to switch into while computing the amount. |

Positional order: `area`.

Alias: `space` for `discount_space`.

Because the tag declares `addAttr`, any other attribute you pass is forwarded
to the underlying routine as an option.

## Description

`[fly-tax]` calculates tax as `taxable amount * rate`, where the rate comes
from the catalog `TAXRATE` Variable rather than a
[SalesTax](../config/SalesTax.md) table. It is the mechanism behind the
common "flat variable" tax setup, where `SalesTax` is set to a tag that calls
`[fly-tax]`.

The tag reads several catalog Variables (`__NAME__` settings) at runtime:

- `TAXRATE` — a comma-separated list of `region=rate` pairs, for example
  `CA=7.25, NY=8.0, DEFAULT=0`. A rate greater than 1 is treated as a
  percentage and divided by 100.
- `TAXCOUNTRY` — if set, tax is only computed when the customer's `country`
  value field matches one of the listed countries; otherwise the tag returns
  `0`.
- `TAXSHIPPING` — a list of regions for which the shipping cost is added to
  the taxable amount before the rate is applied.
- `TAXHANDLING` — a list of regions for which the handling cost is added to
  the taxable amount.

If no `area` is given, the tag derives one by walking the field names listed
in the `SalesTax` directive and using the first non-empty customer value
field (typically `state` or `zip`). Region matching is case-insensitive.

If the region is not found in `TAXRATE`, or no rate resolves, the tag returns
`0`.

## Examples

With `TAXRATE` set to `CA=7.25, DEFAULT=0` in the catalog, tax the current
cart for California:

    [fly-tax area=CA]

produces, for a $100 taxable cart:

    7.25

Let the tag pick the region from the customer's `state` value field (the
usual configuration):

    [fly-tax]

Wire it up as the catalog tax engine in `catalog.cfg` so that
[salestax](salestax.md) formats and returns the result:

    Variable  TAXRATE   CA=7.25, NY=8.0, DEFAULT=0
    SalesTax  [fly-tax]

## Notes

`[fly-tax]` returns an unformatted number. To display it as currency, wrap it
in [currency](currency.md), or configure it through `SalesTax` and use
[salestax](salestax.md), which applies currency formatting.

## See also

- [salestax](salestax.md)
- [handling](handling.md)
- [shipping](shipping.md)
- [currency](currency.md)
- [SalesTax](../config/SalesTax.md)
- Concepts: [taxes](../guides/taxes.md)

## Source

Defined in `code/SystemTag/fly_tax.coretag`. Implemented by
`Vend::Interpolate::fly_tax`.
