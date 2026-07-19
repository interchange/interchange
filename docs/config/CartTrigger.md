# CartTrigger

Names Perl subroutines to invoke whenever the contents of a shopping cart
change through Interchange's standard order processing. Reach for it to enforce
business rules on the cart -- cascading quantities, bundling, logging -- as
items are added, updated, or deleted.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    CartTrigger  subroutine_name ...

A whitespace- or comma-separated list of `Sub` or [GlobalSub](GlobalSub.md)
names, or a single inline `sub { ... }` code block. The directive accumulates,
so multiple lines add to the list of triggers. Default: empty (no triggers).

## Description

Each named subroutine fires whenever the cart is modified through the standard
Interchange CGI variable space -- that is, through the [process](../tags/process.md)
action's `mv_order_item` / `mv_order_quantity` handling, or from a standard cart
page. Triggers fire per change, so a single page submission that alters several
lines can call each subroutine several times.

Every trigger subroutine is called with five arguments:

1. A reference to the cart (an arrayref of hashref line items).
2. The action that fired the trigger: `add`, `update`, or `delete`.
3. A hashref for the new row (undefined on `delete`).
4. A hashref for the old row (undefined on `add`; on `update`, a copy of the
   row before the change, no longer a member of the cart).
5. The symbolic name of the cart.

Return values from each call are collected into an array that is returned when
the firing completes, but the current cart code does not act on those values.

By default a change to an item's quantity alone does not fire triggers; set
[CartTriggerQuantity](CartTriggerQuantity.md) to `Yes` to include quantity
updates.

## Examples

Cascade a master item's quantity to its sub-items (in `catalog.cfg`):

```
Sub <<EOS
sub cascade_quantities {
    my ($cartref, $action, $newref, $oldref, $cartname) = @_;

    # act on the main cart only
    return unless $cartname eq 'main';

    if ($action eq 'update' && $newref->{mv_si} == 0
        && $newref->{quantity} != $oldref->{quantity}) {
        for my $subref (grep {$_->{mv_mi} eq $newref->{mv_mi}} @$cartref) {
            $subref->{quantity} = $newref->{quantity};
        }
    }
}
EOS

CartTrigger cascade_quantities
CartTriggerQuantity Yes
```

## Notes

Interchange carts are plain arrayrefs of hashrefs with no access
encapsulation, so directly manipulating cart contents from your own Perl does
*not* fire these triggers. They fire only when the cart is changed through the
standard CGI-based processing.

## See also

[CartTriggerQuantity](CartTriggerQuantity.md), [GlobalSub](GlobalSub.md),
[UseModifier](UseModifier.md), the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

## Source

Parsed by `parse_routine_array` in `lib/Vend/Config.pm`; triggers are fired by
`trigger` in `lib/Vend/Cart.pm` from the add/update/delete paths in
`lib/Vend/Cart.pm` and `lib/Vend/Order.pm`.
