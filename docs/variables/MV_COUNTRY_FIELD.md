# MV_COUNTRY_FIELD

Names the values field that holds the customer's country code during order
checking. Reach for it when your forms store the country in a field other than
`country`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_COUNTRY_FIELD  fieldname

`fieldname` is a form/values field name. Default: `country`.

## Description

Order-checking routines in `lib/Vend/Order.pm` read the customer's country from
the values field named by `MV_COUNTRY_FIELD` (for example, when guessing a
credit-card type by country, and when applying country-specific state/zip
checks). When unset, the field name `country` is used.

## Examples

Read the country from a differently named field:

    Variable  MV_COUNTRY_FIELD  ship_country

## Notes

The historic manual described this variable as the country field used in
tax/VAT calculation. In the current code, tax/VAT calculation
(`tax_vat` in `lib/Vend/Interpolate.pm`) instead reads `MV_COUNTRY_TAX_VAR`
(default `country`); `MV_COUNTRY_FIELD` is used by the order checks in
`lib/Vend/Order.pm`. See [MV_COUNTRY_TABLE](MV_COUNTRY_TABLE.md) and
[MV_COUNTRY_TAX_FIELD](MV_COUNTRY_TAX_FIELD.md) for the tax-table settings.

## See also

[MV_STATE_REQUIRED](MV_STATE_REQUIRED.md),
[MV_ZIP_REQUIRED](MV_ZIP_REQUIRED.md),
[MV_COUNTRY_TABLE](MV_COUNTRY_TABLE.md), the
[cart-and-checkout](../guides/cart-and-checkout.md) and
[taxes](../guides/taxes.md) guides.

## Source

Consumed in `lib/Vend/Order.pm` via `$::Variable->{MV_COUNTRY_FIELD}`.
