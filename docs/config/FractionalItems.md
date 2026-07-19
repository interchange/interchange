# FractionalItems

Allows non-integer quantities in the shopping cart. Reach for it when you sell
goods measured by weight, length, or volume -- fabric, produce, cable -- where
a line item quantity of `2.5` is meaningful.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    FractionalItems  yes|no

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`). Default: `No`.

## Description

By default Interchange treats item quantities as whole numbers: when a quantity
is set, everything after the decimal point is stripped, so `2.5` becomes `2`.

With `FractionalItems` enabled, that truncation is suppressed and fractional
quantities are kept as entered. This affects the quantity stored on the cart
line and, through it, extended-price and quantity-based calculations.

The setting governs quantity handling only; it does not change how prices are
formatted or divided (see [PriceDivide](PriceDivide.md) and
[PriceCommas](PriceCommas.md) for that).

## Examples

Permit fractional quantities in `catalog.cfg`:

```
FractionalItems Yes
```

A customer can now order `1.75` of an item and have that quantity preserved
through checkout, rather than being rounded down to `1`.

## Notes

Leaving `FractionalItems` off (the default) forces integer quantities, which is
what most catalogs want. Enable it only where partial units genuinely make
sense, and make sure your pricing and inventory logic can handle fractional
amounts.

## See also

[SeparateItems](SeparateItems.md), [PriceDivide](PriceDivide.md),
[OrderLineLimit](OrderLineLimit.md), the
[cart-and-checkout](../guides/cart-and-checkout.md) and
[pricing](../guides/pricing.md) guides.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Order.pm`, where quantity is truncated with `s/\..*//` unless
`$Vend::Cfg->{FractionalItems}` is set.
