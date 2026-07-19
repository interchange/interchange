# OrderLineLimit

Caps the number of separate line items a cart may hold. Reach for it to defend
against badly behaved robots that follow every "add to cart" link and bloat the
session.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    OrderLineLimit  count

A single integer. Default: `0` (no limit).

## Description

Each time the cart is updated, `lib/Vend/Order.pm` checks the number of line
items against `OrderLineLimit`. If the limit is reached, the entire cart is
emptied, a warning is logged, and the lockout handler runs:

```perl
if($Vend::Cfg->{OrderLineLimit} and $#$cart >= $Vend::Cfg->{OrderLineLimit}) {
    @$cart = ();
    ...
    do_lockout($msg);
}
```

The lockout invokes the global [LockoutCommand](LockoutCommand.md) if one is
configured. A runaway robot that keeps adding items therefore trips the limit,
loses its cart, and is subject to whatever lockout action you defined, sparing
the server the cost of repeatedly saving and restoring an oversized cart.

## Examples

Limit carts to 200 line items -- the strap demo's setting (in `catalog.cfg`):

```
OrderLineLimit 200
```

## Notes

Set the limit well above the largest cart a real customer would ever build, so
that only abusive request patterns can reach it.

## See also

[LockoutCommand](LockoutCommand.md), [RobotLimit](RobotLimit.md),
[NotRobotUA](NotRobotUA.md), the [security](../guides/security.md) guide.

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{OrderLineLimit}` in `lib/Vend/Order.pm`.
