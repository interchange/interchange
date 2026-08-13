# DiscountSpacesOn

Enables the "discount spaces" feature, which lets a catalog keep several
independent sets of discounts and switch between them per request or per cart.
Reach for it when a single visitor session needs more than one discount context
(for example, one discount set per named cart).

**Scope:** catalog (`catalog.cfg`)

## Syntax

    DiscountSpacesOn  yes|no

A yes/no boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default:
`No`.

## Description

Interchange normally keeps one discount table per session. With
`DiscountSpacesOn` enabled, the session holds a hash of named discount
"spaces", each an independent discount table, and the active space can be
changed at runtime.

When the feature is on, a per-request dispatch routine initializes the current
space to `main` and then checks the CGI variables named by
[DiscountSpaceVar](DiscountSpaceVar.md); the first one that is set selects the
active discount space for that request. Space switching is also driven by the
`discount_space` option accepted by discount-aware tags (interpolation calls
`switch_discount_space` in `lib/Vend/Interpolate.pm`).

When the feature is off, all discount-space operations are no-ops: the active
space is always `main`, and any attempt to select an alternate space has no
effect. Requesting a non-existent space while the feature is off logs an error
to the catalog error log.

## Examples

Turn the feature on in `catalog.cfg`:

```
DiscountSpacesOn Yes
```

Enable it and tie the discount space to the current cart name instead of the
default variable:

```
DiscountSpacesOn Yes
DiscountSpaceVar mv_cartname
```

## See also

[DiscountSpaceVar](DiscountSpaceVar.md), the
[pricing](../guides/pricing.md) and
[cart-and-checkout](../guides/cart-and-checkout.md) guides.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Interpolate.pm` (`switch_discount_space`) and by the
`DiscountSpaces` per-request dispatch routine in `lib/Vend/Config.pm`.
