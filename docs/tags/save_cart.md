# save_cart

Save the shopper's current cart under a nickname in the user database, so a
logged-in customer can restore it later. Reach for it to implement "save this
cart" or wish-list features. This is the counterpart of
[load_cart](load_cart.md) and [delete_cart](delete_cart.md).

## Syntax

    [save_cart nickname="wishlist"]
    [save_cart nickname="monthly" recurring=1 keep=1]

Standalone tag (no end tag). Returns the empty string; its effect is the
database write.

## Attributes

| Attribute   | Default | Description |
|-------------|---------|-------------|
| `nickname`  |         | Name to store the cart under (positional 1). Alias: `name`. |
| `recurring` | `0`     | Mark the saved cart as recurring (`r`) rather than a one-time cart (`c`) (positional 2). |
| `keep`      | `0`     | Keep the current (`main`) cart after saving; otherwise it is emptied (positional 3). |

Positional order: `nickname`, `recurring`, `keep`. Alias: `name` for
`nickname`.

## Description

The tag persists the current cart into the logged-in user's saved-cart store
via `[userdb function=set_cart]`. Colons are stripped from `nickname` (they are
the field separator in the saved-cart list). If a cart of the same type
(recurring vs. one-time) is already saved under that nickname, a numeric suffix
(`nickname,1`, `nickname,2`, …) is appended so the existing one is not
overwritten.

After a successful save, the current `main` cart is emptied unless `keep` is
true — the common "move cart to saved list" behavior. If the underlying
[userdb](userdb.md) call fails (for example, no user is logged in), nothing is
saved.

The saved carts are exposed to pages through the `carts` value, which
[save_cart] reads to detect nickname collisions.

## Examples

Save the current cart as a wish list and empty the working cart:

    [save_cart nickname="wishlist"]

Save without clearing the working cart:

    [save_cart nickname="wishlist" keep=1]

As a form action target:

    <form action="[process]" method=post>
    <input type=hidden name="mv_todo" value="return">
    <input type=hidden name="mv_nextpage" value="ord/basket">
    Name this cart: <input name="cart_name" value="">
    <input type=submit value="Save cart">
    </form>

then, on the return page:

    [save_cart nickname="[value cart_name]"]

## Notes

- The shopper must be logged in; saved carts live in the user database keyed to
  the account. See the [user-database guide](../guides/user-database.md).
- Nicknames are made unique per type by suffixing, so saving twice under the
  same name yields two entries, not an overwrite.

## See also

- [load_cart](load_cart.md) — restore a saved cart
- [delete_cart](delete_cart.md) — remove a saved cart
- [userdb](userdb.md) — the underlying account operations
- The [cart-and-checkout guide](../guides/cart-and-checkout.md)

## Source

Defined in `code/UserTag/save_cart.tag` (inline `Routine`); stores via
`[userdb function=set_cart]`.
