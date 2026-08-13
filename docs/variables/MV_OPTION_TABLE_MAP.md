# MV_OPTION_TABLE_MAP

Remaps the field names Interchange expects in the product option table to the
field names your table actually uses. Reach for it when your options table has
different column names from the built-in defaults.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_OPTION_TABLE_MAP  "field1=field2 field3=field4"

A quoted, space-delimited list of `expected=actual` pairs. Default: unset (no
remapping).

## Description

The options subsystem reads `MV_OPTION_TABLE_MAP` as a set of `field=field`
mappings and uses them to translate the option field names it expects into the
columns present in [MV_OPTION_TABLE](MV_OPTION_TABLE.md). This lets an existing
table schema work without renaming columns.

## Examples

Map two internal field names onto existing columns:

    Variable  MV_OPTION_TABLE_MAP  "o_group=optgroup o_value=optval"

## See also

[MV_OPTION_TABLE](MV_OPTION_TABLE.md), the [pricing](../guides/pricing.md)
guide.

## Source

Consumed in `lib/Vend/Config.pm`, `lib/Vend/Data.pm`, and
`lib/Vend/Options/Old48.pm` via `$::Variable->{MV_OPTION_TABLE_MAP}`.
