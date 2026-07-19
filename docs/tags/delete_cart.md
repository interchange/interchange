# delete_cart

Delete a saved, nicknamed shopping cart from the logged-in user's account in
the user database. The counterpart to saving a cart under a nickname for later
retrieval.

## Syntax

    [delete_cart NICKNAME]
    [delete_cart nickname=NICKNAME]

Standalone tag. Always returns the empty string.

## Attributes

| Attribute  | Default | Description |
|------------|---------|-------------|
| `nickname` |         | Nickname of the saved cart to delete (first positional). |

Positional order: `nickname`.
Alias: `name` for `nickname`.

## Description

The tag calls the user database `delete_cart` function (equivalent to
`[userdb function=delete_cart nickname=...]`), which removes the named saved
cart from the current user's stored carts. It requires a logged-in user; saved
carts live in the user database, so there is nothing to delete for an anonymous
session. The tag produces no output -- use it for its side effect.

Saved carts are created by the matching save-cart operation and listed from the
user's account; see [../guides/user-database.md](../guides/user-database.md)
and [../guides/cart-and-checkout.md](../guides/cart-and-checkout.md).

## Examples

Delete the saved cart nicknamed `wishlist`:

    [delete_cart wishlist]

Delete a cart whose nickname comes from a form field, using the `name` alias:

    [delete_cart name="[value cartname]"]

## See also

[userdb](userdb.md),
[value](value.md),
[../guides/user-database.md](../guides/user-database.md),
[../guides/cart-and-checkout.md](../guides/cart-and-checkout.md)

## Source

Defined in `code/UserTag/delete_cart.tag`. Implemented by the inline Routine in
that file, which dispatches to `Vend::UserDB` via the [userdb](userdb.md) tag.
