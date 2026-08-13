# OrderCleanup

Registers one or more subroutines to run after an order is placed, to tidy up
whatever the checkout process left behind. Reach for it to clear custom scratch
or session data once an order is complete.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    OrderCleanup  name ...
    OrderCleanup  sub { ... }

A comma- or space-separated list of [Sub](Sub.md)/[GlobalSub](GlobalSub.md)
names, or a single inline `sub { ... }` block. The directive accumulates, so
several lines (or several names) build up a list of routines. Default: empty.

## Description

After Interchange finishes displaying the order-confirmation route and empties
the cart, `lib/Vend/Dispatch.pm` runs the registered cleanup routines:

```perl
# Do order cleanup
run_macro($Vend::Cfg->{OrderCleanup});
```

`run_macro` invokes each named subroutine (or the inline block) in turn. Use it
for post-order housekeeping the checkout flow does not do for you -- resetting a
custom counter, clearing scratch variables tied to the just-completed order, or
notifying an external system.

## Examples

Run a named subroutine after each order (in `catalog.cfg`):

```
Sub clear_order_state
    sub {
        delete $Vend::Session->{scratch}{quote_id};
        return;
    }
EndSub

OrderCleanup clear_order_state
```

Provide the cleanup inline instead:

```
OrderCleanup sub { delete $Vend::Session->{scratch}{quote_id}; return; }
```

## See also

[AutoEnd](AutoEnd.md), [Autoload](Autoload.md), [Sub](Sub.md),
[GlobalSub](GlobalSub.md), the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

## Source

Parsed by `parse_routine_array` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{OrderCleanup}` (through `run_macro`) in `lib/Vend/Dispatch.pm`.
