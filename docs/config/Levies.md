# Levies

Lists which defined [Levy](Levy.md) sections are active for the catalog --
that is, which order-level charges (sales tax, shipping, handling, custom
fees) the levy engine actually computes. Reach for it to switch the modern
levy-based tax/shipping totalling on and choose the levies to apply.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Levies  NAME...

A whitespace/comma-separated list of levy names, appended to an array. Each
name must correspond to a [Levy](Levy.md) definition. Default: empty (levy
engine inactive).

## Description

Defining a [Levy](Levy.md) only registers it in the levy repository;
`Levies` is what activates it. When `Levies` is non-empty, the total
routine calls the levy engine, which evaluates each named levy in turn and
appends its computed line (tax, shipping, and so on) to the order. Levy
lines are emitted in `sort`-key order.

If `Levies` names a levy that was never defined, that entry is logged as an
error and skipped. If `Levies` is empty, the levy engine does not run and
tax/shipping are handled by the older mechanisms.

The directive is read at catalog configuration time.

## Examples

Activate the `salestax` and `shipping` levies defined above them:

```
Levies  salestax shipping
```

## Notes

Order matters only through each levy's `sort` key, not through the order of
names in `Levies`. Use [Levy](Levy.md)'s `sort` to control the sequence of
charge lines.

## See also

[Levy](Levy.md), [SalesTax](SalesTax.md), [Shipping](Shipping.md),
[TaxInclusive](TaxInclusive.md), the [taxes](../guides/taxes.md) and
[shipping](../guides/shipping.md) guides.

## Source

Parsed by `parse_array` in `lib/Vend/Config.pm`; the active list drives the
`levies` routine in `lib/Vend/Interpolate.pm`.
