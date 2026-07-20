# MV_TAX_CATEGORY_FIELD

Names the product field that assigns items to a tax category, used when tax
rates vary by category of goods. Reach for it when that field is named
something other than `tax_category`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_TAX_CATEGORY_FIELD  fieldname

`fieldname` is a product field (colon-separated names are accepted for multiple
fields). Default: `tax_category`.

## Description

When a tax definition uses per-category rates, `tax_vat` reads each item's tax
category from the product field named by `MV_TAX_CATEGORY_FIELD`, unless a
`tax_category_field` option overrides it on the call. When neither is set, it
defaults to `tax_category`. The value may name multiple fields separated by
colons.

## Examples

Use a differently named category field:

    Variable  MV_TAX_CATEGORY_FIELD  taxclass

## See also

[MV_TAX_TYPE_FIELD](MV_TAX_TYPE_FIELD.md),
[MV_STATE_TABLE](MV_STATE_TABLE.md), the [taxes](../guides/taxes.md) guide.

## Source

Consumed in `lib/Vend/Interpolate.pm` (`tax_vat`) via
`$::Variable->{MV_TAX_CATEGORY_FIELD}`.
