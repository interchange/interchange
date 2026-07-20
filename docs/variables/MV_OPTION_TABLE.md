# MV_OPTION_TABLE

Names the database table that holds product option data (for Simple, Matrix,
and Modular options). Reach for it when your option data lives in a table other
than the default.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_OPTION_TABLE  table

`table` is a table name. Default: `options`.

## Description

Product options look up their definitions in the table named by
`MV_OPTION_TABLE`. When it is not set, Interchange defaults to `options`, the
single table that holds Simple, Matrix, and Modular option data in the standard
demos (from Interchange 4.9.8 onward). It is read at catalog configuration time
and by the options subsystem.

Use [MV_OPTION_TABLE_MAP](MV_OPTION_TABLE_MAP.md) to remap the field names
Interchange expects within that table.

## Examples

Use a custom options table:

    Variable  MV_OPTION_TABLE  product_options

## See also

[MV_OPTION_TABLE_MAP](MV_OPTION_TABLE_MAP.md), the
[pricing](../guides/pricing.md) guide.

## Source

Consumed in `lib/Vend/Config.pm`, `lib/Vend/Options.pm`, and
`lib/Vend/Options/Simple.pm` via `$::Variable->{MV_OPTION_TABLE}`.
