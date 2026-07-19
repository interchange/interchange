# TaxShipping

Names the shipping modes whose shipping cost is itself taxable, so tax is
charged on shipping as well as on goods. Reach for it where the law taxes
freight for some or all delivery methods.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    TaxShipping  mode ...

A whitespace-separated list of shipping-mode codes (the same codes used in
`mv_shipmode`, such as `default`, `upsg`, `usps`). The raw string is stored
as-is. Default: empty (shipping is not taxed).

## Description

When computing sales tax, Interchange checks the current shipping mode codes
against `TaxShipping`. If a code matches (as a whole word, case-insensitively),
the current shipping charge is added to the taxable amount before the tax rate
is applied. With the default empty value, shipping is never taxed.

## Examples

Tax shipping for the standard and UPS ground modes (in `catalog.cfg`):

```
TaxShipping  default upsg
```

The strap demo wires this to a build-time variable:

```
TaxShipping  __TAXSHIPPING__
```

## Notes

Matching is by whole-word regular expression against the shipping mode codes, so
listing a mode that is a substring of another still matches only on word
boundaries. Whether the resulting tax is added on top or is treated as already
included depends on [TaxInclusive](TaxInclusive.md).

## See also

[TaxInclusive](TaxInclusive.md), [SalesTax](SalesTax.md),
[CustomShipping](CustomShipping.md), [DefaultShipping](DefaultShipping.md), the
[taxes](../guides/taxes.md) and [shipping](../guides/shipping.md) guides.

## Source

Stored unparsed (no parse routine) in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Interpolate.pm` via `$Vend::Cfg->{TaxShipping}` during the sales-tax
calculation (the `CHECKSHIPPING` block).
