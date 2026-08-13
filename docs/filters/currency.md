# currency

Formats a number as a currency amount according to the catalog's locale
settings.

## Syntax

    [filter currency]NUMBER[/filter]
    [filter currency.LOCALE]NUMBER[/filter]
    [value name=field filter="currency"]

The optional dotted argument `LOCALE` names a locale to format in. When it
is given, the value is also currency-converted for that locale; when it is
omitted, the catalog's current locale is used and no conversion is done.

## Description

The filter calls `Vend::Util::currency`, which applies the active locale's
currency rules: the number of decimal places
([PriceDivide](../config/PriceDivide.md)/precision), the thousands
separator ([PriceCommas](../config/PriceCommas.md)), and any currency
symbol configured for the locale. With no argument the amount is formatted
in the catalog's current locale. When a `LOCALE` argument is supplied, the
filter passes a true "convert" flag, so the amount is converted to that
locale's currency before formatting (see [Locale](../config/Locale.md)
for how conversion rates and formats are defined).

The exact output therefore depends on the catalog's locale configuration.
The examples below show a catalog with default (US-style) currency
formatting.

## Examples

    [filter currency]40.2[/filter]

produces (with default formatting, two decimal places):

    40.20

Formatting in a specific locale:

    [filter currency.fr_FR]40.2[/filter]

formats and converts the value for the `fr_FR` locale, using that locale's
separators, decimal places, and any configured currency symbol.

## See also

- [commify](commify.md)
- [round](round.md)
- [Locale](../config/Locale.md)
- [PriceCommas](../config/PriceCommas.md)
- [PriceDivide](../config/PriceDivide.md)
- [pricing guide](../guides/pricing.md)

## Source

Defined in `code/Filter/currency.filter`. Formatting is done by
`Vend::Util::currency` in `lib/Vend/Util.pm`.
