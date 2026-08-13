# MV_MENU_DIRECTORY

Sets the directory the [menu](../tags/menu.md) tag reads menu-definition files
from. Reach for it to keep menu files somewhere other than the default
`include/menus`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_MENU_DIRECTORY  directory

`directory` is a path (relative to the catalog) holding menu files. Default:
`include/menus`.

## Description

When the menu subsystem loads a menu from a file, it uses the directory named
by `MV_MENU_DIRECTORY`, defaulting to `include/menus` when the variable is
unset. This governs file-based menus; database-backed menus use
[MV_TREE_TABLE](MV_TREE_TABLE.md).

## Examples

Store menu files under a custom directory:

    Variable  MV_MENU_DIRECTORY  templates/menus

## See also

[MV_TREE_TABLE](MV_TREE_TABLE.md), [menu](../tags/menu.md), the
[templating](../guides/templating.md) guide.

## Source

Consumed in `lib/Vend/Menu.pm` via `$::Variable->{MV_MENU_DIRECTORY}`.
