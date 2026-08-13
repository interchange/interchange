# UseModifier

Declares the item attributes (modifiers) that may be attached to each line item
in the shopping cart, such as `size` or `color`. Reach for it when products have
variant options that must travel with the item through the order.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    UseModifier  name ...

A whitespace- or comma-separated list of attribute names, appended to an array,
so multiple lines accumulate. Default: empty (no extra modifiers). Certain names
are reserved and rejected as illegal: `mv_mi`, `mv_si`, `mv_ib`, `group`,
`code`, `sku`, `quantity`, `item`, and other `mv_` names.

## Description

Each name in `UseModifier` becomes a field carried on every cart line item.
Interchange preserves these values as the item moves through the cart and order,
and they are available to pricing, display, and order routines. This is how a
single SKU can be ordered in a chosen size or color: the option is stored on the
line item rather than requiring a separate SKU.

Modifiers are commonly populated from an option table via the
[accessories](../tags/accessories.md) tag on the flypage or item page.

## Examples

Allow `size` and `color` modifiers on items (in `catalog.cfg`):

```
UseModifier  size,color
```

After adding the `size` and `color` columns to the product data, display the
size options for a SKU on a page with:

```
[accessories os28004 size]
```

## Notes

The names listed above are reserved for Interchange's own line-item bookkeeping
and cause a configuration error if used as modifier names. A locale-specific
override can change the modifier set (for example a different set under a
`Locale` block); a setting made for an item under one locale is retained if a
later locale does not override it.

## See also

[AutoModifier](AutoModifier.md), [OptionsEnable](OptionsEnable.md),
[Options](Options.md), [SeparateItems](SeparateItems.md), the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

## Source

Parsed by `parse_array` in `lib/Vend/Config.pm` (illegal values enforced via
`%IllegalValue`); consumed in `lib/Vend/Order.pm` and
`lib/Vend/Interpolate.pm` via `$Vend::Cfg->{UseModifier}`.
