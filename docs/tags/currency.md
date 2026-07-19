# currency

Formats the number in its body as localized currency — applying the
thousands separator, decimal point, precision, and currency symbol of the
active locale. Reach for it to display a raw amount (a calculated total, a
database value) with the same formatting Interchange gives prices.

## Syntax

    [currency]12345.6[/currency]
    [currency convert=1 display=text locale=fr_FR]...amount...[/currency]

Container tag (has an end tag). The body is interpolated first, then
treated as the amount to format.

## Attributes

| Attribute  | Default  | Description |
|------------|----------|-------------|
| `convert`  | `0`      | Divide the amount by the locale's `PriceDivide` before formatting. |
| `noformat` | `0`      | Return the amount unformatted (after any conversion). |
| `display`  | `symbol` | Currency symbol style: `symbol`, `text` (ISO code), or `none`. |
| `locale`   | (active) | Format using a specific locale instead of the current one. |

Positional order: `convert`, `noformat`. `[currency]` accepts arbitrary
additional attributes (`addAttr`).

## Description

The tag wraps `Vend::Util::currency`. It takes the interpolated body as a
numeric amount and formats it according to the currency settings of the
active locale (`mv_currency`, the catalog `Locale`, or a locale you name
with `locale=`):

- With `convert=1`, the amount is first divided by the locale's
  `PriceDivide` value. This is the standard mechanism for storing prices in
  one base currency and displaying them in another.
- `noformat=1` returns the (possibly converted) amount with no separators,
  symbol, or fixed precision.
- The separators and precision come from the locale
  (`mon_thousands_sep`, `mon_decimal_point`, `frac_digits`, or an explicit
  `price_picture`). With no locale configured the tag falls back to plain
  `%.2f` formatting.
- `display` chooses how the currency symbol is shown: the locale symbol,
  the international/ISO text code, or nothing.

The same formatting routine is applied automatically by the price-bearing
tags — [price](price.md), [subtotal](subtotal.md),
[salestax](salestax.md), and [total-cost](total-cost.md) — so `[currency]`
is what you use to format amounts those tags do not already produce.

## Examples

Format a literal amount (with no locale configured, US formatting):

    [currency]4[/currency]

produces:

    4.00

Format the result of a calculation:

    [currency][calc]500.00 + 1000.00[/calc][/currency]

With `PriceDivide` set to `0.167` and `convert=1`, the same sum displays
converted and formatted for the active locale.

Format a database value as currency:

    [currency][data table=products column=price key=os28004][/currency]

## Notes

The tag formats whatever number the body evaluates to; it does not look up
a product price itself (use [price](price.md) for that). A non-numeric body
formats as `0.00` under most locales.

## See also

[price](price.md), [subtotal](subtotal.md), [salestax](salestax.md),
[total-cost](total-cost.md),
[PriceDivide](../config/PriceDivide.md),
[Locale](../config/Locale.md), the
[internationalization](../guides/internationalization.md) and
[pricing](../guides/pricing.md) guides.

## Source

Defined in `code/SystemTag/currency.coretag` (inline `Routine`), which
calls `Vend::Util::currency` in `lib/Vend/Util.pm`.
