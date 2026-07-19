# item-list

Iterates over the line items in a shopping cart, emitting its body once per
item with a set of `item-` prefix sub-tags available for each row. Reach for it
to build a basket display, an order summary, or a receipt line list.

## Syntax

    [item-list] ... item body ... [/item-list]
    [item-list cart=name reverse=1 prefix=item] ... [/item-list]

Container tag (has an end tag). The body is a loop template: it is *not*
interpolated once, but repeated and interpolated per item, with the sub-tags
below resolved against the current line.

## Attributes

| Attribute         | Default  | Description |
|-------------------|----------|-------------|
| `cart`            | current  | Name of the cart to iterate; default is the current cart. |
| `reverse`         | `0`      | Iterate items in reverse (last added first). |
| `prefix`          | `item`   | Sub-tag prefix for this loop. |
| `discount_space`  | (none)   | Switch to this discount namespace for the loop. |

Positional order: `name` (the cart). Aliases: `cart` for `name`, `space` for
`discount_space`. The tag accepts arbitrary additional attributes (`addAttr`),
which are available to sub-tags as loop options.

## Description

The tag's inline routine selects the item list — the named cart's array, or the
current cart (`$Vend::Items`) when no cart is named — optionally reverses it,
and runs it through `labeled_list`, the same list engine used by
[loop](loop.md) and search results. Each element is one cart line: a hash of the
SKU, quantity, and any modifiers.

### Prefix sub-tags

Within the loop, per-row data is reached through `item-` prefixed sub-tags (the
prefix follows the `prefix=` attribute). The full sub-tag model, shared by all
looping tags, is described in
[Templating with ITL](../guides/templating.md#loops-and-prefix-sub-tags). The
ones specific to cart lines include:

- `[item-code]` / `[item-sku]` — the line's product code
- `[item-quantity]` — quantity ordered
- `[item-field col]` — a column from the products table for this SKU
- `[item-data table col]` — a column from any table, keyed by the SKU
- `[item-description]` — the product description
- `[item-price]`, `[item-subtotal]`, `[item-discount-price]` — line pricing
- `[item-modifier name]` / `[item-param name]` — an item modifier (option) value
- `[item-accessories ...]` — build option widgets for the line
- `[item-increment]` — the 1-based row number
- `[item-next] ... [/item-next]`, `[item-last] ... [/item-last]` — run code on
  a given pass
- `[if-item-field col] ... [/if-item-field]` — row-level conditional

## Examples

Minimal basket listing:

    [item-list]
    [item-quantity] x [item-description] @ [item-price]
    [/item-list]

A cart table (adapted from the strap `cart_tiny` component):

    [item-list]
      [item-next][item-modifier mv_si][/item-next]
      <tr>
        <td><a href="[area [item-sku]]">[item-filter 20][item-data products
    description][/item-filter]</a></td>
        <td>[item-quantity] x [item-discount-price]</td>
      </tr>
    [/item-list]

Iterate a named cart in reverse:

    [item-list cart=wishlist reverse=1]
    [item-code]
    [/item-list]

## Notes

- With no `cart`, `[item-list]` follows the current cart, which
  [cart](cart.md) can change. Passing `cart=` here does not change the current
  cart for other tags.
- The body is a loop template; a bare `[item-list][/item-list]` with an empty
  body returns nothing.

## See also

- [loop](loop.md) — the general list iterator with the same sub-tag model
- [cart](cart.md) — set the current cart
- [nitems](nitems.md), [subtotal](subtotal.md) — cart totals
- Guide: [Templating with ITL](../guides/templating.md)

## Source

Defined in `code/SystemTag/item_list.coretag` (inline `Routine`, which calls
`labeled_list` in `lib/Vend/Interpolate.pm`).
