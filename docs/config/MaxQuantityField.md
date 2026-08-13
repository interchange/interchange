# MaxQuantityField

Names database columns that hold the maximum order quantity allowed per item.
Reach for it to cap how many of a product a customer can put in the cart, for
example to enforce available stock.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    MaxQuantityField  [=|?]field ...

One or more field specifications, stored verbatim (no parser is run). Each
field is either `column` (looked up in the item's own table, falling back to
the first [ProductFiles](ProductFiles.md) table) or `table:column`. Multiple
fields are separated by commas and/or whitespace. Default: empty (no maximum
enforced).

## Description

Whenever the cart is refreshed, `lib/Vend/Cart.pm` looks up the maximum
quantity for each line item. For a bare `column`, the table defaults to the
table the item came from (`mv_ib`) or, failing that, the first
[ProductFiles](ProductFiles.md) table; a `table:column` form names the table
explicitly. If the item's code has no matching record, the item is treated as
unlimited.

When several fields are listed, their values are summed to produce the
maximum. A field may carry a leading prefix to change how it combines with the
others (applied to the `table:column` form):

| Prefix | Effect |
|--------|--------|
| (none) | add this field's value to the running maximum |
| `=`    | override: use this field's value as the maximum outright |
| `?`    | override only if this field's value is greater than zero |

If a line's quantity exceeds the computed maximum, Interchange lowers it to the
maximum and flags the item with `mv_max_over`.

## Examples

Cap each item at the on-hand count in the `inventory` table (as shipped,
commented, in the strap `catalog.cfg`):

```
MaxQuantityField  inventory:quantity
```

Use a column in the default product table:

```
MaxQuantityField  max_quantity
```

Sum several fields (commas and whitespace are interchangeable separators):

```
MaxQuantityField  inventory:quantity, products:in_stock products:on_hand
```

Override the running total with `products:on_hand` only when it is greater
than zero:

```
MaxQuantityField  inventory:quantity ?products:on_hand
```

## Notes

The `=` and `?` prefixes are recognized on the table portion of a field, so use
the `table:column` form when applying them.

## See also

[MinQuantityField](MinQuantityField.md), [ProductFiles](ProductFiles.md),
[OrderLineLimit](OrderLineLimit.md), the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

## Source

Stored unparsed (no `parse_*` routine) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{MaxQuantityField}` in `lib/Vend/Cart.pm`.
