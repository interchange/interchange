# SeparateItems

Controls whether ordering more than one of the same item adds a separate cart
line for each, rather than bumping the quantity on a single line. Reach for it
when each instance of a part number needs its own attributes -- a different
size, color, or personalization.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SeparateItems  yes|no

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default: `No`.

## Description

By default Interchange aggregates identical items: adding the same SKU again
just increases the quantity on the existing cart line. With `SeparateItems`
enabled, each added item becomes its own line even when the SKU matches, so line
attributes (modifiers such as color or size) can differ between instances of the
same product.

This catalog-wide setting is the default for new items and can be overridden per
request through the `mv_separate_items` variable, supplied as a form/URL value
or set in [scratch](../glossary.md). When `mv_separate_items` is present it wins
over the directive.

## Examples

Treat each ordered item as its own cart line. In `catalog.cfg`:

```
SeparateItems  Yes
```

Override for a single add-to-cart form by aggregating instead:

```
<input type="hidden" name="mv_separate_items" value="0">
```

## See also

[UseModifier](UseModifier.md), [AutoModifier](AutoModifier.md),
[FractionalItems](FractionalItems.md), the
[cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`. Consumed in
`lib/Vend/Order.pm` (`add_item`), where `mv_separate_items` may override it.
