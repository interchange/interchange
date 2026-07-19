# nitems

Return the total quantity of items in a shopping cart. Reach for it to show
a "N items in your cart" count in a header or basket summary.

## Syntax

    [nitems]
    [nitems name=cartname lines=1 qualifier=attr compare=regex]

Standalone tag. Output is a plain number and is not reparsed.

## Attributes

| Attribute   | Default    | Description |
|-------------|------------|-------------|
| `name`      | current cart | Name of the cart to count. |
| `lines`     | `0`        | Count the number of distinct line items instead of summing quantities. |
| `qualifier` | (none)     | An item attribute that must be true for the line to be counted. |
| `compare`   | (none)     | A regular expression matched against the `qualifier` attribute; the line is counted only when it matches. |

Positional order: `name`.

## Description

Interchange keeps each shopping cart as a list of line items, every line
carrying a `quantity` and any modifiers. `[nitems]` walks that list and, by
default, adds up the `quantity` of every line, returning the grand total.
With no `name`, it counts the current cart (`main` unless you have switched
carts).

`lines=1` returns the count of distinct lines instead of the summed
quantity — three of one SKU plus two of another is `5` normally but `2`
with `lines=1`.

`qualifier` restricts the count to lines whose named modifier attribute is
true. Add `compare` to test that attribute against a regular expression
rather than mere truth, so only lines whose attribute matches are counted.

If the named cart does not exist, the tag returns `0`.

## Examples

Total items in the current cart:

    You have [nitems] items in your cart.

produces, for a cart holding 3 of one product and 2 of another:

    You have 5 items in your cart.

Count distinct lines instead:

    [nitems lines=1]

produces:

    2

Count only lines flagged as a subscription:

    [nitems qualifier=subscription]

## See also

- [item-list](item-list.md) — iterate the cart's lines
- [cart](cart.md) — reference a named cart
- [value](value.md), [subtotal](subtotal.md)
- Cart concepts: [cart and checkout](../guides/cart-and-checkout.md)

## Source

Defined in `code/SystemTag/nitems.coretag`. Implemented by
`Vend::Util::tag_nitems` (`lib/Vend/Util.pm`).
