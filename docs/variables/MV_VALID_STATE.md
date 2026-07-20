# MV_VALID_STATE

Overrides the built-in list of valid US state codes used by the `state` order
check. Reach for it to accept a custom set of state/territory abbreviations.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_VALID_STATE  "CA NY TX ..."

A whitespace-separated list of accepted state codes. Default: unset (the
built-in US state template is used).

## Description

The `_state` order-check routine validates a submitted state against
`MV_VALID_STATE` when it is set, matching the value (case-insensitively) as a
whitespace-delimited token in the list. When unset, Interchange uses its
built-in US state list. A value not found in the effective list produces a
validation error.

## Examples

Accept only a few states plus a territory:

    Variable  MV_VALID_STATE  "CA NY TX PR"

Use with a form profile order check:

    &fatal=yes
    state=required
    state=state

## See also

[MV_VALID_PROVINCE](MV_VALID_PROVINCE.md),
[MV_STATE_REQUIRED](MV_STATE_REQUIRED.md), the
[order-checks](../order-checks/README.md) reference and the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

## Source

Consumed in `lib/Vend/Order.pm` (`_state`) via
`$::Variable->{MV_VALID_STATE}`.
