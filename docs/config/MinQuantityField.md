# MinQuantityField

Names a database column that holds the minimum order quantity required per
item. Reach for it to enforce a minimum purchase amount, such as products sold
only in batches.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    MinQuantityField  [table:]column

A single field specification, stored verbatim (no parser is run). Either
`column` (looked up in the item's own table, falling back to the first
[ProductFiles](ProductFiles.md) table) or `table:column`. Default: empty (no
minimum enforced).

## Description

When the cart is refreshed, `lib/Vend/Cart.pm` looks up the minimum quantity
for each line item. For a bare `column`, the table defaults to the table the
item came from (`mv_ib`) or, failing that, the first
[ProductFiles](ProductFiles.md) table; a `table:column` form names the table
explicitly. If the item's code has no matching record the lookup yields an
empty value and no minimum is enforced.

If the ordered quantity is below the looked-up minimum, Interchange raises the
line's quantity up to that minimum and flags the item with `mv_min_under`.
Unlike [MaxQuantityField](MaxQuantityField.md), only a single field is
consulted and the `=`/`?` prefixes are not used.

## Examples

Require at least the `min_quantity` value from the default product table:

```
MinQuantityField  min_quantity
```

Take the minimum from a column in the `inventory` table:

```
MinQuantityField  inventory:min_batch
```

## Notes

Historic documentation described the default table as the `products` database.
In the current code the table for a bare column defaults to the item's own
source table (`mv_ib`) and only then to the first
[ProductFiles](ProductFiles.md) table, which is typically -- but not
necessarily -- `products`.

## See also

[MaxQuantityField](MaxQuantityField.md), [ProductFiles](ProductFiles.md),
[OrderLineLimit](OrderLineLimit.md), the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

## Source

Stored unparsed (no `parse_*` routine) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{MinQuantityField}` in `lib/Vend/Cart.pm`.
