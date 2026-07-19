# PriceDivide

Sets the number every raw price is divided by to get the displayed amount.
Reach for it when prices are stored in a smaller unit than the currency you
display -- for example integer cents that should show as dollars.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    PriceDivide  number

A number (the divisor). Default: `1` (prices are used as stored).

## Description

After Interchange computes an item's cost it divides the result by
`PriceDivide` before display. Store prices in cents and set `PriceDivide
100` to show dollars; leave it at `1` to use stored values unchanged. The
division is applied in `lib/Vend/Data.pm` after chained-cost resolution.

If the value is ever non-numeric or zero (which would be a division error),
Interchange logs an error naming the current currency/locale and resets
`PriceDivide` to `1` for that calculation rather than failing.

## Examples

Prices are stored in pennies (in `catalog.cfg`):

```
PriceDivide 100
```

Vary the divisor by locale:

```
# Default is 1, so no setting needed for the base currency
Locale fr_FR  PriceDivide  .20
```

## Notes

A [Locale](Locale.md) definition can set `PriceDivide` per currency; because
`PriceDivide` is one of the locale-adjustable directives, a currency switch
overrides the catalog-level value. This is how the same stored figure can
map to different amounts in different currencies.

## See also

[PriceCommas](PriceCommas.md), [PriceField](PriceField.md),
[CommonAdjust](CommonAdjust.md), [Locale](Locale.md), the
[pricing](../guides/pricing.md) and
[internationalization](../guides/internationalization.md) guides.

## Source

Stored with no parser (raw value) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{PriceDivide}` in `lib/Vend/Data.pm` and `lib/Vend/Util.pm`.
