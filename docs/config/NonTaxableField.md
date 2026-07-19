# NonTaxableField

Names the product-table column that marks an item as exempt from sales tax.
Reach for it when some products in your catalog are not taxable and the flag
lives in the database.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    NonTaxableField  column

A single database column name, stored verbatim (no parser is run). Default:
empty (the feature is disabled).

## Description

When `NonTaxableField` is set, Interchange excludes an item from the taxable
subtotal if that item's value in the named column is a "true" value (`1`,
`Yes`, `on`, and similar). The taxable-amount routine in
`lib/Vend/Interpolate.pm` returns the full subtotal when the directive is
empty, and otherwise tests each line item:

```perl
next if is_yes( item_field($item, $Vend::Cfg->{NonTaxableField}) );
```

The column is looked up in the item's product table. If the named column does
not exist in the table, Interchange logs an error and the item is taxed
anyway, so the field you name must exist for every product table involved. The
per-line flag `mv_nontaxable` is also honored independently of this directive.

The newer `Vend::Tax` subsystem likewise reads `NonTaxableField` as the default
for its `nontaxable_field` parameter.

## Examples

Treat products with a true value in the `nontaxable` column as tax-exempt (as
used by the strap pricing profiles in `catalog.cfg`):

```
NonTaxableField nontaxable
```

## See also

[SalesTax](SalesTax.md), [TaxShipping](TaxShipping.md),
[TaxInclusive](TaxInclusive.md), the [taxes](../guides/taxes.md) guide.

## Source

Stored unparsed (no `parse_*` routine) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{NonTaxableField}` in `taxable_amount` in
`lib/Vend/Interpolate.pm` (and as a default in `lib/Vend/Tax.pm`).
