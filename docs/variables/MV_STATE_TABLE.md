# MV_STATE_TABLE

Names the database table used to look up per-state tax information during
tax calculation. Reach for it when your state tax data lives in a table other
than `state`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_STATE_TABLE  table

`table` is a table name. Default: `state`.

## Description

When a country's tax type points to a state-based lookup, `tax_vat` reads the
state's tax from the table named by `MV_STATE_TABLE`, unless a `state_table`
option overrides it on the call. When neither is set, it defaults to `state`.
The column read is set by [MV_STATE_TAX_FIELD](MV_STATE_TAX_FIELD.md).

## Examples

Use a custom state tax table:

    Variable  MV_STATE_TABLE  us_states

## See also

[MV_STATE_TAX_FIELD](MV_STATE_TAX_FIELD.md),
[MV_COUNTRY_TABLE](MV_COUNTRY_TABLE.md),
[MV_TAX_TYPE_FIELD](MV_TAX_TYPE_FIELD.md), the [taxes](../guides/taxes.md)
guide.

## Source

Consumed in `lib/Vend/Interpolate.pm` (`tax_vat`) via
`$::Variable->{MV_STATE_TABLE}`.
