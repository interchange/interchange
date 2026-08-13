# SalesTaxFunction

Supplies custom Perl that returns the sales-tax rate table, overriding the
built-in table lookup. Reach for it when your tax rates depend on logic --
a vendor, a lookup service, or a computed schedule -- that a static table
cannot express.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SalesTaxFunction  PERL_CODE
    SalesTaxFunction  SUBROUTINE_NAME

The value is stored verbatim (no parser). It may be a block of Perl (given
inline, usually in a here-document) or the name of a
[Sub](Sub.md)/[GlobalSub](GlobalSub.md); it is evaluated with `tag_calc`.
Default: empty.

## Description

When set (and [SalesTax](SalesTax.md) is not `multi` and does not contain
ITL), Interchange evaluates `SalesTaxFunction` to obtain the tax-rate hash
in place of reading the `salestax` table. The code is run through
`tag_calc`, so `$Session`, `$Values`, `$Scratch`, and the other embedded
Perl objects are available.

The function must return a Perl hash reference keyed by the same codes
Interchange would otherwise look up (for example uppercase state or country
codes), with rate values. **The hash must include a `DEFAULT` key** --
without it, Interchange finds no default row and the tax comes out as zero
unconditionally. The result is consumed in `lib/Vend/Interpolate.pm`.

## Examples

Return a fixed schedule of state rates:

```
SalesTaxFunction  <<EOR
return {
  DEFAULT => 0.0,
  IL => 0.075,
  OH => 0.065,
};
EOR
```

Compute the table from a per-vendor search, ensuring `DEFAULT` is set:

```
SalesTaxFunction  <<EOR
my $vendor_id = $Session->{source};
my $tax_hash = $TextSearch->hash( {
  se => $vendor_id,
  fi => 'salestax.asc',
  sf => 'vendor_code',
  ml => 1000,
} );
$tax_hash = {} if ! $tax_hash;
$tax_hash->{DEFAULT} = 0;
return $tax_hash;
EOR
```

Delegate to a subroutine defined elsewhere:

```
SalesTaxFunction  custom_tax_routine
```

## Notes

Always set `DEFAULT` in the returned hash; a missing default silently
yields zero tax. Embedded Perl runs under `Safe` restrictions; see
[SafeUntrap](SafeUntrap.md) if the code needs an otherwise-forbidden
operation.

## See also

[SalesTax](SalesTax.md), [TaxShipping](TaxShipping.md),
[Sub](Sub.md), [GlobalSub](GlobalSub.md), the
[taxes](../guides/taxes.md) and
[perl-embedding](../guides/perl-embedding.md) guides.

## Source

Stored unparsed by `catalog_directives()` in `lib/Vend/Config.pm`;
evaluated via `tag_calc` and consumed in `lib/Vend/Interpolate.pm`.
