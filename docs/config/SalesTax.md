# SalesTax

Selects how Interchange calculates sales tax on an order: from a lookup
table keyed by form fields, from a VAT-style multi-rate table, or from an
Interchange Tag Language (ITL) expression. Reach for it to set your
catalog's basic tax method.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SalesTax  multi
    SalesTax  field[,field...]
    SalesTax  [ITL expression]

The value is stored verbatim (no parser) and interpreted by its form.
Default: empty (no tax).

| Form                | Meaning                                             |
|---------------------|-----------------------------------------------------|
| `multi`             | Use the multi-rate / VAT table lookup (`tax_vat`).  |
| contains `[`        | Interpolate the value as ITL; its result is the tax amount. |
| one or more field names | A comma/space list of form-value field names, in priority order, used to look up a rate in the `salestax` table. |

## Description

When an order needs a tax figure, Interchange inspects `SalesTax`:

- The literal `multi` routes to the VAT/multi-rate machinery, which reads
  rates from a tax table (typically driven by `country` and `state`).
- A value containing a `[` is treated as ITL, interpolated for each
  calculation; the interpolated result is used as the tax amount. This is
  how a custom tax tag or service is plugged in.
- Otherwise the value is a list of field names from the submitted form.
  Interchange upper-cases each corresponding value and uses them, in the
  order given, as keys into the sales-tax rate table, falling back to a
  `DEFAULT` entry.

If [SalesTaxFunction](SalesTaxFunction.md) is set and `SalesTax` is not one
of the first two forms, the function supplies the rate table instead. The
calculation is performed in `lib/Vend/Interpolate.pm`.

## Examples

Look up the rate by ZIP and then state (from the historic default style):

```
SalesTax zip,state
```

Use a form field defined elsewhere via a variable (from the strap
`catalog.cfg`, where `__TAXFIELD__` expands to the chosen field or a tax
tag):

```
SalesTax __TAXFIELD__
```

Delegate the whole calculation to an ITL tax service tag:

```
SalesTax [tax-lookup service=taxjar]
```

## Notes

The rate table used for the field-list form is the `salestax` data (often
loaded from `salestax.asc`); its `DEFAULT` row is applied when no keyed row
matches. Whether shipping is taxed is governed separately by
[TaxShipping](TaxShipping.md).

## See also

[SalesTaxFunction](SalesTaxFunction.md), [TaxShipping](TaxShipping.md),
[TaxInclusive](TaxInclusive.md), [NonTaxableField](NonTaxableField.md), the
[taxes](../guides/taxes.md) guide.

## Source

Stored unparsed by `catalog_directives()` in `lib/Vend/Config.pm`;
consumed in `lib/Vend/Interpolate.pm` (the `salestax` calculation).
