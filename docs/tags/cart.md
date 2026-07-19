# cart

Sets the current shopping cart, so that later cart-aware tags on the page
operate on that cart instead of the default `main` cart. Reach for it when a
catalog uses more than one named cart (for example a wishlist or a
saved-for-later basket) and you need a block of tags to act on one of them.

## Syntax

    [cart name]
    [cart name=nickname]

Standalone tag (no end tag). It produces no output; it only changes state.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | `main`  | Name (nickname) of the cart to make current. |

Positional order: `name`.

## Description

Interchange keeps every shopping cart in the session under a nickname; the
default cart is called `main`. This tag maps to `Vend::Interpolate::tag_cart`,
which simply sets the package variable `$Vend::CurrentCart` to the name you
pass. From that point on, tags that read "the current cart" —
[nitems](nitems.md), [subtotal](subtotal.md), [shipping](shipping.md),
[salestax](salestax.md), [total-cost](total-cost.md) and the like — report on
the named cart until another `[cart]` (or the end of the request) changes it.

The tag does not create the cart or verify that it exists; naming a cart that
has never held an item simply makes the current-cart totals empty. To iterate
the line items of a specific cart directly, pass its name to
[item-list](item-list.md) instead (which has its own `cart` attribute and does
not disturb the current-cart setting).

## Examples

Switch the current cart to one named `layaway`:

    [cart layaway]

Report the item count and subtotal of a secondary cart, then switch back:

    [cart wishlist]
    Wishlist: [nitems] items, subtotal [subtotal]
    [cart main]

## See also

- [item-list](item-list.md) — iterate a cart's line items
- [nitems](nitems.md), [subtotal](subtotal.md), [total-cost](total-cost.md)
- [delete_cart](delete_cart.md), [load_cart](load_cart.md)
- Guide: [Templating with ITL](../guides/templating.md)

## Source

Defined in `code/SystemTag/cart.coretag`. Implemented by
`Vend::Interpolate::tag_cart` in `lib/Vend/Interpolate.pm`.
