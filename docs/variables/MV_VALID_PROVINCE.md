# MV_VALID_PROVINCE

Overrides the built-in list of valid Canadian province codes used by the
`province` order check. Reach for it to accept a custom set of province/
territory abbreviations.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_VALID_PROVINCE  "ON QC BC ..."

A whitespace-separated list of accepted province codes. Default: unset (the
built-in Canadian province template is used).

## Description

The `_province` order-check routine validates a submitted province against
`MV_VALID_PROVINCE` when it is set, matching the value (case-insensitively) as a
whitespace-delimited token. When unset, Interchange uses its built-in Canadian
province list. A value not found in the effective list produces a validation
error.

## Examples

Accept a specific set of provinces:

    Variable  MV_VALID_PROVINCE  "ON QC BC AB MB"

## See also

[MV_VALID_STATE](MV_VALID_STATE.md),
[MV_STATE_REQUIRED](MV_STATE_REQUIRED.md), the
[order-checks](../order-checks/README.md) reference and the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

## Source

Consumed in `lib/Vend/Order.pm` (`_province`) via
`$::Variable->{MV_VALID_PROVINCE}`.
