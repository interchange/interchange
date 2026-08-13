# TaxInclusive

Treats displayed product prices as already including tax, so Interchange backs
the tax out of the price instead of adding it on top. Reach for it in
jurisdictions (commonly European VAT) where shelf prices are quoted
tax-inclusive.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    TaxInclusive  Yes|No

A boolean (`Yes`/`No`, `1`/`0`, `on`/`off`, `true`/`false`). Default: `No`.

## Description

With `TaxInclusive` set, Interchange assumes the price a customer sees already
contains the tax. Rather than computing `price * rate` and adding it, it divides
the rate out with `rate / (1 + rate)` so the tax figure it reports is the tax
component already contained in the total, and it does not add a separate tax
line to the order subtotal. This affects the sales-tax calculation in
`lib/Vend/Interpolate.pm` (the `[salestax]` tag and levy handling).

## Examples

Enable tax-inclusive pricing (in `catalog.cfg`):

```
TaxInclusive  Yes
```

## Notes

`TaxInclusive` changes only how the tax amount is derived and displayed; the
tax rate itself still comes from your [SalesTax](SalesTax.md) /
[SalesTaxFunction](SalesTaxFunction.md) configuration. Combine with
[TaxShipping](TaxShipping.md) if shipping is also taxed.

## See also

[TaxShipping](TaxShipping.md), [SalesTax](SalesTax.md),
[SalesTaxFunction](SalesTaxFunction.md), [Levies](Levies.md), the
[taxes](../guides/taxes.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Interpolate.pm` via `$Vend::Cfg->{TaxInclusive}` during sales-tax
calculation.
