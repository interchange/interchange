# load_cart

Load a previously saved (nicknamed) shopping cart out of the user database
and merge it into the visitor's current cart. Reach for it to implement
"saved carts", wishlists, or recurring-order restore for a logged-in user.

## Syntax

    [load_cart NICKNAME]
    [load_cart nickname="NICKNAME"]

Standalone tag (no end tag). Produces no output; it works by side effect,
returning the empty string.

## Attributes

| Attribute  | Default  | Description |
|------------|----------|-------------|
| `nickname` | *(none)* | The saved-cart identifier to load. Usually the full colon-delimited value `name:time:recurflag` produced by [save_cart](save_cart.md). |

Alias: `name` for `nickname`.

Positional order: `nickname`.

## Description

`[load_cart]` calls the [userdb](userdb.md) `get_cart` function with
`merge => 1`, which reads the named cart from the logged-in user's account
and merges its items into the current main cart. It then sets the scratch
variable `just_nickname` to the base name portion of the nickname (the text
before the first colon) so a template can display which cart was loaded.

The nickname is treated as a colon-delimited string of `name:time:recur`,
matching what [save_cart](save_cart.md) stores. If the recurring flag (the
third field) is the letter `c` (a one-time "cart", not a recurring order),
the loaded cart is then deleted from the user database with the `userdb`
`delete_cart` function — loading a one-time saved cart consumes it.

The visitor must be logged in (have an active user-database account) for
there to be saved carts to load.

## Examples

Load a saved cart by its full nickname:

    [load_cart mycart:990102732:c]

Named-attribute form:

    [load_cart nickname="mycart:990102732:c"]

Loop over a user's saved carts and offer a load link for each (the `carts`
value holds the list `save_cart` maintains):

    [loop list="[value carts]" delimiter="\n"]
      <a href="[area href=ord/basket form=`'mv_nextpage=ord/basket'`]">
        [loop-code]</a>
      [tmp cart_nick][loop-code][/tmp]
      [load_cart nickname="[loop-code]"]
    [/loop]

## Notes

- `[load_cart]` and [save_cart](save_cart.md) are a pair; the demo ships
  the `templates/components/saved_carts_list_small` component that lists and
  restores saved carts.
- Loading merges into (does not replace) the current cart, so items already
  in the basket remain.

## See also

- [save_cart](save_cart.md) — store the current cart under a nickname
- [delete_cart](delete_cart.md) — remove a saved cart
- [userdb](userdb.md) — the user-database function this tag drives
- [../guides/cart-and-checkout.md](../guides/cart-and-checkout.md)

## Source

Defined in `code/UserTag/load_cart.tag` (registers the tag `load_cart`).
Implemented by an inline Routine that calls the [userdb](userdb.md)
`get_cart`/`delete_cart` functions.
