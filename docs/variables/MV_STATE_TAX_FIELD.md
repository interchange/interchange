# MV_STATE_TAX_FIELD

Names the field in the state table that holds a state's tax rate. Reach for it
when that column is named something other than `tax`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_STATE_TAX_FIELD  fieldname

`fieldname` is a column in the state table. Default: `tax`.

## Description

During state-based tax calculation, `tax_vat` reads the tax value for the
customer's state from the field named by `MV_STATE_TAX_FIELD` in
[MV_STATE_TABLE](MV_STATE_TABLE.md), unless a `state_tax_field` option
overrides it on the call. When neither is set, it defaults to `tax`.

## Examples

Read the state tax from a differently named column:

    Variable  MV_STATE_TAX_FIELD  rate

## See also

[MV_STATE_TABLE](MV_STATE_TABLE.md),
[MV_TAX_TYPE_FIELD](MV_TAX_TYPE_FIELD.md), the [taxes](../guides/taxes.md)
guide.

## Source

Consumed in `lib/Vend/Interpolate.pm` (`tax_vat`) via
`$::Variable->{MV_STATE_TAX_FIELD}`.
