# MV_TAX_TYPE_FIELD

Names the field in the state table that identifies the tax type/name, used when
selecting among multiple tax rows. Reach for it when that column is named
something other than `tax_name`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_TAX_TYPE_FIELD  fieldname

`fieldname` is a column in the state table. Default: `tax_name`.

## Description

When `tax_vat` narrows a state tax lookup by tax type, it matches against the
field named by `MV_TAX_TYPE_FIELD`, unless a `tax_type_field` option overrides
it on the call. When neither is set, it defaults to `tax_name`.

## Examples

Use a differently named tax-type column:

    Variable  MV_TAX_TYPE_FIELD  tax_kind

## See also

[MV_STATE_TABLE](MV_STATE_TABLE.md),
[MV_TAX_CATEGORY_FIELD](MV_TAX_CATEGORY_FIELD.md), the
[taxes](../guides/taxes.md) guide.

## Source

Consumed in `lib/Vend/Interpolate.pm` (`tax_vat`) via
`$::Variable->{MV_TAX_TYPE_FIELD}`.
