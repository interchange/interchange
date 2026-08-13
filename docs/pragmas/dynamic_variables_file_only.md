# dynamic_variables_file_only

Restricts dynamic variable lookups to files, preventing Interchange from opening
databases while resolving `Variable` values. Set it alongside
[dynamic_variables](dynamic_variables.md) when your dynamic variables live only
in [DirConfig](../config/DirConfig.md) files and you do not want the overhead or
side effects of a database lookup.

**Default:** off — dynamic lookups may fall through to the
[VariableDatabase](../config/VariableDatabase.md).

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma dynamic_variables_file_only

Page-wide, anywhere in an Interchange page:

    [pragma dynamic_variables_file_only]
    [pragma dynamic_variables_file_only 0]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma dynamic_variables_file_only]1[/tag]

This is a boolean pragma.

## Description

The `dynamic_var()` routine resolves a variable first from a `DirConfig`
`Variable` file, then (if none exists) from the
[VariableDatabase](../config/VariableDatabase.md), then from the in-memory
`$::Variable` value. When `dynamic_variables_file_only` is set, the database step
is skipped entirely, so a name not found in a file falls straight through to the
in-memory value.

This pragma has no effect unless [dynamic_variables](dynamic_variables.md) is
also enabled — dynamic lookup is what it constrains.

## Examples

Enable dynamic variables from files only. In `catalog.cfg`:

    Pragma dynamic_variables
    Pragma dynamic_variables_file_only

## Notes

Only meaningful in combination with [dynamic_variables](dynamic_variables.md)
plus [DirConfig](../config/DirConfig.md); on its own it does nothing.

## See also

- [dynamic_variables](dynamic_variables.md)
- [DirConfig](../config/DirConfig.md)
- [VariableDatabase](../config/VariableDatabase.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `dynamic_var()` in
`lib/Vend/Interpolate.pm`.
