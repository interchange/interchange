# MV_TREE_TABLE

Names the database table that holds tree (hierarchical menu) data. Reach for it
when your menu tree lives in a table other than the default `tree`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_TREE_TABLE  table

`table` is a table name. Default: `tree`.

## Description

The menu subsystem reads hierarchical menu data from the table named by
`MV_TREE_TABLE`, unless a `table` option overrides it on the tag call. When
neither is set, it defaults to `tree`. This is used by the tree/menu display
code and by the admin menu editor.

## Examples

Use a custom tree table:

    Variable  MV_TREE_TABLE  navigation

## See also

[MV_MENU_DIRECTORY](MV_MENU_DIRECTORY.md), [menu](../tags/menu.md), the
[templating](../guides/templating.md) guide.

## Source

Consumed in `lib/Vend/Menu.pm` via `$::Variable->{MV_TREE_TABLE}`.
