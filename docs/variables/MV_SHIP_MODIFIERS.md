# MV_SHIP_MODIFIERS

Lists extra item attributes that shipping calculations should carry along as
per-item modifiers. Reach for it when your shipping logic needs item-level data
(such as weight class or handling flags) beyond the standard fields.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_SHIP_MODIFIERS  "mod1 mod2 ..."

A list of modifier names separated by whitespace, commas, or vertical bars.
Default: unset.

## Description

During shipping calculation, `lib/Vend/Ship.pm` reads `MV_SHIP_MODIFIERS`,
splits it on whitespace/comma/bar, and makes each named item modifier available
to the shipping code. This lets custom shipping formulas reference item
attributes that are not part of the default set.

## Examples

Expose two item modifiers to shipping:

    Variable  MV_SHIP_MODIFIERS  "weight handling_class"

## See also

[MV_SHIP_ADDRESS_TEMPLATE](MV_SHIP_ADDRESS_TEMPLATE.md), the
[shipping](../guides/shipping.md) guide.

## Source

Consumed in `lib/Vend/Ship.pm` (`shipping`) via
`$::Variable->{MV_SHIP_MODIFIERS}`.
