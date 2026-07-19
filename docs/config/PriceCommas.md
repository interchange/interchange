# PriceCommas

Controls whether formatted prices include the locale's thousands separator.
Reach for it to suppress (or restore) the grouping character in displayed
currency amounts.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    PriceCommas  Yes|No

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default: `Yes`.

## Description

When Interchange formats a currency value for display -- for example through
the [currency](../tags/currency.md) filter or the item price tags -- it
groups the integer part with the locale's `mon_thousands_sep` (set through
[Locale](Locale.md)) only when `PriceCommas` is on. Turn it off to render
prices with no grouping character. The grouping is applied by the currency
formatter in `lib/Vend/Util.pm`, which calls `commify` only when
`$Vend::Cfg->{PriceCommas}` is true.

Despite the name, the character inserted is whatever the active locale
defines, which need not be a comma.

## Examples

Render prices without a thousands separator (in `catalog.cfg`):

```
PriceCommas 0
```

Vary the setting by locale:

```
# Default
PriceCommas    1

# Locale-specific overrides
Locale fr_FR  PriceCommas  0
Locale en_US  PriceCommas  1
```

## Notes

A [Locale](Locale.md) `price_picture` definition overrides this directive:
when a price picture is in effect, it fully controls formatting and
`PriceCommas` is not consulted.

## See also

[PriceDivide](PriceDivide.md), [PriceField](PriceField.md),
[Locale](Locale.md), [currency](../tags/currency.md), the
[pricing](../guides/pricing.md) and
[internationalization](../guides/internationalization.md) guides.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{PriceCommas}` in `lib/Vend/Util.pm`.
