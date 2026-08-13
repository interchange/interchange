# discount_space

Switch or manage the active discount namespace (a "discount space") for
the current session. Reach for it when a catalog uses several shopping
carts at once and you need each cart to carry its own set of discounts
without item codes leaking from one cart into another.

## Syntax

    [discount_space NAME]
    [discount_space name=NAME clear=1]
    [discount_space current=1]

Standalone tag (no end tag). It returns nothing in normal use; with
`current=1` it returns the name of the active space.

## Attributes

| Attribute | Default  | Description |
|-----------|----------|-------------|
| `name`    | `main`   | Name of the discount space to switch to; positional parameter 1. |
| `clear`   | (off)    | After switching, empty all discounts in the selected space. |
| `current` | (off)    | Do not switch; just return the name of the currently active space. |

Positional order: `name`.

Alias: `space` for `name`.

## Description

Interchange normally keeps every discount (see [discount](discount.md)) in
a single per-session hash. When a store uses multiple carts through
`mv_cartname` to represent fundamentally different transactions, discounts
keyed by the same item code in different carts would collide. A discount
space gives each cart its own discount namespace.

The tag maintains a master hash of named spaces in the session and repoints
the active discount hash at the space you name. The default space is
`main`, mirroring the default cart name. Passing a `name` makes that space
active (creating it if needed); subsequent [discount](discount.md) tags
then read and write that space.

- `clear=1` switches to the named space and then empties its discounts.
- `current=1` leaves the active space unchanged and returns its name.

This feature is inert unless the
[DiscountSpacesOn](../config/DiscountSpacesOn.md) directive is enabled. If
you call the tag with spaces deactivated, it logs an error and does
nothing.

## Examples

Switch discount handling to the space named `wholesale`:

    [discount_space wholesale]

Switch to that space and wipe any discounts already in it:

    [discount_space name=wholesale clear=1]

Show which space is currently active:

    Current discount space: [discount_space current=1]

Typical pairing with a named cart and a discount:

    [discount_space wholesale]
    [discount ALL_ITEMS]$s * 0.85[/discount]

## Notes

The default space name is `main`; it is created on first use and always
holds whatever was in the session's original discount hash, so existing
single-space catalogs keep working unchanged.

## See also

[discount](discount.md),
[DiscountSpacesOn](../config/DiscountSpacesOn.md), the
[cart and checkout](../guides/cart-and-checkout.md) and
[pricing](../guides/pricing.md) guides.

## Source

Defined in `code/SystemTag/discount_space.coretag` (inline `Routine`). The
active space is stored in `$Vend::Session->{discount_space}` and read by
`Vend::Interpolate::discount_price` in `lib/Vend/Interpolate.pm`.
