# MV_COMPONENT_DIR

Sets the directory the [component](../tags/component.md) tag looks in for
component files. Reach for it to keep components somewhere other than the
default `templates/components`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_COMPONENT_DIR  directory

`directory` is a path (relative to the catalog) holding component files.
Default: `templates/components`.

## Description

The `component` user tag resolves a component name to a file by looking in the
directory named by `MV_COMPONENT_DIR`. When the variable is unset, it looks in
`templates/components`. Components are reusable page fragments assembled into
pages.

## Examples

Store components under a custom directory:

    Variable  MV_COMPONENT_DIR  include/components

## See also

[MV_COMPONENT_TABLE](MV_COMPONENT_TABLE.md), [component](../tags/component.md),
the [templating](../guides/templating.md) guide.

## Source

Consumed in `code/UserTag/component.tag` via
`$::Variable->{MV_COMPONENT_DIR}`.
