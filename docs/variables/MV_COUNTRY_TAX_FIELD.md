# MV_COUNTRY_TAX_FIELD

Names the field in the country table that holds a country's tax type or rate.
Reach for it when that column is named something other than `tax`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_COUNTRY_TAX_FIELD  fieldname

`fieldname` is a column in the country table. Default: `tax`.

## Description

During VAT/tax calculation, `tax_vat` reads the tax value for the customer's
country from the field named by `MV_COUNTRY_TAX_FIELD` in
[MV_COUNTRY_TABLE](MV_COUNTRY_TABLE.md), unless a `country_tax_field` option
overrides it on the call. When neither is set, it defaults to `tax`.

## Examples

Read the country tax from a differently named column:

    Variable  MV_COUNTRY_TAX_FIELD  vat_rate

## See also

[MV_COUNTRY_TABLE](MV_COUNTRY_TABLE.md),
[MV_STATE_TAX_FIELD](MV_STATE_TAX_FIELD.md), the [taxes](../guides/taxes.md)
guide.

## Source

Consumed in `lib/Vend/Interpolate.pm` (`tax_vat`) via
`$::Variable->{MV_COUNTRY_TAX_FIELD}`.
