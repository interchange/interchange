# CartTriggerQuantity

Controls whether a change to an existing cart item's quantity fires the
subroutines named in [CartTrigger](CartTrigger.md). Reach for it when your
triggers need to react to quantity edits, not just item additions and
removals.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    CartTriggerQuantity  yes|no

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default: `No`.

## Description

By default, [CartTrigger](CartTrigger.md) subroutines fire when an item is
added to or deleted from the cart, but *not* when only the quantity of an
existing line changes. Setting `CartTriggerQuantity Yes` makes quantity changes
on existing items fire the triggers as well (with an action of `update`).

A quantity change to zero deletes the item, so it fires triggers regardless of
this directive's value.

## Examples

Enable quantity-change triggering in `catalog.cfg`:

```
CartTrigger cascade_quantities
CartTriggerQuantity Yes
```

## Notes

This directive has no effect unless [CartTrigger](CartTrigger.md) also names at
least one subroutine.

## See also

[CartTrigger](CartTrigger.md), the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; read alongside `CartTrigger`
in `lib/Vend/Cart.pm` and `lib/Vend/Order.pm`.
