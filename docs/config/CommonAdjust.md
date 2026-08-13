# CommonAdjust

Defines the catalog-wide default for Interchange's chained ("atom-based")
pricing scheme -- the sequence of database lookups and adjustments used to
compute an item's price. Reach for it to drive quantity breaks, attribute
surcharges, and sale prices from your database rather than a flat `price`
column.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    CommonAdjust  common_adjust_string

A single chained-pricing string made of comma-separated *atoms*, read as a raw
value. Default: empty (no common adjustment; the plain price field is used).

## Description

`CommonAdjust` supplies the default pricing chain applied when an item's own
price field does not specify its own chain. Each atom in the string is a
lookup or adjustment step: a `;`-prefixed atom sets a base price, a
`==field:table` atom adds an attribute-based adjustment from another table, and
quantity-break columns (`qN`) select a price by ordered quantity. Atoms are
evaluated left to right, each acting on the running price.

The chain is consumed by the price-calculation code (`chain_cost`) whenever an
item's price is computed. The full atom syntax, and the interaction with
[PriceField](PriceField.md), [PriceDivide](PriceDivide.md), and pricing set
through a [Profile](Profile.md), are covered in the
[pricing](../guides/pricing.md) guide; read it before building a chain.

## Examples

The strap demo's default direct-purchase chain (in `catalog.cfg`): a quantity
break from a `pricing` table, then the item's `sale_price`, then `price`, then
related-item and options adjustments:

```
CommonAdjust   pricing:q5,q10 ;:sale_price, ;:price, ;$, :related, ==:options
PriceField     0
```

Set a size-based surcharge from a `pricing` table by writing the chain into the
product's own `price` field instead of the directive:

```
10.00, ==size:pricing
```

## Notes

Most practical setups keep the adjustment data in a separate (outboard)
`pricing` table rather than in the products table. A pricing chain can be set
per-item in the `price` field, per-profile through [Profile](Profile.md), or
catalog-wide through this directive; the item's own field takes precedence over
the `CommonAdjust` default.

## See also

[PriceField](PriceField.md), [PriceDefault](PriceDefault.md),
[PriceDivide](PriceDivide.md), [Profile](Profile.md),
[UseModifier](UseModifier.md), the [pricing](../guides/pricing.md) guide.

## Source

Parsed with no parser (raw string) in `lib/Vend/Config.pm`; consumed by
`chain_cost` in `lib/Vend/Data.pm`.
