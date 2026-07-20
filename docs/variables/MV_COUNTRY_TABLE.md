# MV_COUNTRY_TABLE

Names the database table used to look up per-country tax information during
VAT/tax calculation. Reach for it when your country tax data lives in a table
other than `country`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_COUNTRY_TABLE  table

`table` is a table name. Default: `country`.

## Description

The `tax_vat` routine looks up the tax type for a customer's country in the
table named by `MV_COUNTRY_TABLE`, unless a `country_table` option overrides it
on the call. When neither is set, it defaults to `country`. The field read from
this table is set by [MV_COUNTRY_TAX_FIELD](MV_COUNTRY_TAX_FIELD.md).

## Examples

Use a custom country table for tax lookups:

    Variable  MV_COUNTRY_TABLE  countries

## See also

[MV_COUNTRY_TAX_FIELD](MV_COUNTRY_TAX_FIELD.md),
[MV_STATE_TABLE](MV_STATE_TABLE.md),
[MV_TAX_TYPE_FIELD](MV_TAX_TYPE_FIELD.md), the [taxes](../guides/taxes.md)
guide.

## Source

Consumed in `lib/Vend/Interpolate.pm` (`tax_vat`) via
`$::Variable->{MV_COUNTRY_TABLE}`.
