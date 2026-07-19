# PriceDefault

Names the price field to use in a chained-pricing lookup when the field part
of a `table:field:key` reference is left blank. Reach for it only when you
use chained pricing (`CommonAdjust`) and want the implicit field to be
something other than `price`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    PriceDefault  field_name

A single database field (column) name. Default: `price`.

## Description

Chained pricing atoms in [CommonAdjust](CommonAdjust.md) can reference a
value with a `table:field:key` specification. When the `field` component is
omitted (a spec like `table::key`), Interchange substitutes the column named
by `PriceDefault`. The substitution is made in the chained-cost logic of
`lib/Vend/Data.pm`, where `$field` defaults to `$Vend::Cfg->{PriceDefault}`
when empty.

## Examples

Keep the default price column (in `catalog.cfg`):

```
PriceDefault price
```

## See also

[PriceField](PriceField.md), [PriceDivide](PriceDivide.md),
[CommonAdjust](CommonAdjust.md), the [pricing](../guides/pricing.md) guide.

## Source

Stored with no parser (raw string) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{PriceDefault}` in `lib/Vend/Data.pm`.
