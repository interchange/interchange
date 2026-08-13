# PriceField

Names the database column Interchange reads an item's price from. Reach for
it when your products table stores the price under a name other than the
default `price`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    PriceField  field_name

A single database field (column) name. A value of `0` disables the direct
field lookup so price comes entirely from [CommonAdjust](CommonAdjust.md)
chained pricing. Default: `price`.

## Description

When Interchange needs an item's base price -- for example to satisfy an
`[item-price]` tag in Interchange Tag Language (ITL) -- it reads the column
named by `PriceField` from the products table. Point this at a different
column when your schema calls the price something else. The lookup is in
`lib/Vend/Data.pm`, which uses `$Vend::Cfg->{PriceField}` when it is set.

Setting `PriceField 0` tells Interchange not to read a price column at all;
in that arrangement, seen in the strap demo, the whole price is built by the
[CommonAdjust](CommonAdjust.md) chain instead.

## Examples

Read the price from a `preis` column (in `catalog.cfg`):

```
PriceField preis
```

Vary the field by locale:

```
# Default at startup
PriceField    price

# Locale-specific column
Locale fr_FR  PriceField  prix
```

Let chained pricing supply the price entirely (as the strap demo does):

```
PriceField 0
```

## See also

[PriceDefault](PriceDefault.md), [PriceDivide](PriceDivide.md),
[PriceCommas](PriceCommas.md), [CommonAdjust](CommonAdjust.md),
[Locale](Locale.md), the [pricing](../guides/pricing.md) guide.

## Source

Stored with no parser (raw string) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{PriceField}` in `lib/Vend/Data.pm`.
