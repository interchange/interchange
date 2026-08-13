# AutoModifier

Declares item attributes (modifiers) that Interchange fills in
automatically from database columns when an item is added to the cart.
Reach for it to attach product data -- weight, price group, tax status,
download flags -- to each cart line without the shopper submitting it.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    AutoModifier  [name=][table:]column[:key] ...

A whitespace-separated list of attribute specifications that accumulates
across lines. Each specification is:

- `column` -- the attribute (and, by default, the source column) name; the
  value comes from that column of the products database for the item.
- `table:column` -- read the column from a specific table.
- `name=...` -- store the value under attribute `name` instead of the
  column name.
- `...:key` -- use the named field's value (for example `mv_sku`) as the
  lookup key instead of the item code.

Certain reserved values (such as `mv_mi`, `code`, `sku`) are rejected as
illegal. Default: empty.

## Description

When an item is added to the cart, `lib/Vend/Cart.pm` (with helpers in
`lib/Vend/Data.pm` and `lib/Vend/Order.pm`) loads each declared attribute
from the specified table/column for that item and stores it on the cart
line. The attribute is then readable as `$item->{name}` in embedded Perl
and through the attribute tags, so custom code -- shipping, discount, tax,
or download logic -- can act on it.

Lookups account for matrix-option products: the item code and its base
SKU are both consulted when resolving the value.

## Examples

Load `nontaxable` from the products table for each line, from the strap
demo `catalog.cfg`:

```
AutoModifier    nontaxable
```

Load a dealer price group from a `pricing` table, also from the strap
demo:

```
AutoModifier pricing:price_group
```

Set an attribute from a different table, with and without renaming:

```
AutoModifier inventory:heavy
AutoModifier weighty=inventory:heavy
```

Use a specific field as the lookup key:

```
AutoModifier inventory:heavy:mv_sku
```

## Notes

Make sure the columns you reference exist in the named table (or in
`products` when no table is given), or the attribute value will be empty.

`UseModifier` declares modifiers supplied by the shopper (for example
option selections); `AutoModifier` declares ones filled in from the
database. The two lists are separate.

## See also

[UseModifier](UseModifier.md), [NonTaxableField](NonTaxableField.md), the [pricing](../guides/pricing.md),
[shipping](../guides/shipping.md), and
[cart-and-checkout](../guides/cart-and-checkout.md) guides.

## Source

Parsed by `parse_array` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{AutoModifier}` in `lib/Vend/Cart.pm`, `lib/Vend/Data.pm`,
and `lib/Vend/Order.pm`.
