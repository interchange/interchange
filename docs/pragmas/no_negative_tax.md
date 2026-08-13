# no_negative_tax

Prevents a sales-tax calculation from producing a negative amount. When set, any
computed tax below zero is reset to zero. Reach for it when discounts or credits
could drive a tax total negative and you want to floor it at zero.

**Default:** off — a negative computed tax is also floored to zero (see Notes).

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma no_negative_tax

Page-wide, anywhere in an Interchange page:

    [pragma no_negative_tax]
    [pragma no_negative_tax 0]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma no_negative_tax]1[/tag]

This is a boolean pragma.

## Description

Interchange's `salestax()` routine checks this pragma at two points:

- When a tax cost was already computed by an earlier routine and is negative,
  the cost is set to `0` **only if** `no_negative_tax` is set.
- When the routine computes the tax itself and the result is negative, the
  result is set to `0` **unless** `no_negative_tax` is set.

In other words, the self-computed path already floors negative tax at zero by
default, and the pragma extends the same flooring to a pre-supplied negative
cost. Setting the pragma guarantees the returned tax is never negative in either
path.

## Examples

Never charge negative tax. In `catalog.cfg`:

    Pragma no_negative_tax

## Notes

Added in Interchange 5.5. Because the two code paths treat the default
differently (see Description), if you rely on custom tax routines that may return
a negative cost, set this pragma explicitly rather than depending on the default.

## See also

- [SalesTax](../config/SalesTax.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `salestax()` in
`lib/Vend/Interpolate.pm`.
