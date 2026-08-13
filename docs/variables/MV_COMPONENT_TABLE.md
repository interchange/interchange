# MV_COMPONENT_TABLE

Names the database table the [component](../tags/component.md) tag reads
component definitions from. Reach for it when components are stored in a table
other than the default.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_COMPONENT_TABLE  table

`table` is a table name. Default: `component`.

## Description

The `component` user tag looks up a component's definition in the table named
by `MV_COMPONENT_TABLE` unless a `comp_table` option overrides it on the tag
call. When neither is set, it defaults to `component`.

## Examples

Use a custom component table:

    Variable  MV_COMPONENT_TABLE  cms_components

## See also

[MV_COMPONENT_DIR](MV_COMPONENT_DIR.md), [component](../tags/component.md),
the [templating](../guides/templating.md) guide.

## Source

Consumed in `code/UserTag/component.tag` via
`$::Variable->{MV_COMPONENT_TABLE}`.
