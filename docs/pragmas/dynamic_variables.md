# dynamic_variables

Enables dynamic lookup of page `Variable` values (`@_NAME_@`, `__NAME__`,
`@@NAME@@`) from files and databases at page-render time, instead of only from
the values loaded at catalog startup. Set it when you use
[DirConfig](../config/DirConfig.md) or
[VariableDatabase](../config/VariableDatabase.md) to store variables outside
`catalog.cfg`.

**Default:** off — variables resolve only from the startup-loaded
`$::Variable` / `$Global::Variable` hashes.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma dynamic_variables

Page-wide, anywhere in an Interchange page:

    [pragma dynamic_variables]
    [pragma dynamic_variables 0]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma dynamic_variables]1[/tag]

This is a boolean pragma.

## Description

When `dynamic_variables` is off, `vars_and_comments()` substitutes each
`@_NAME_@` and `__NAME__` reference from the in-memory `$::Variable` hash (falling
back to `$Global::Variable`). When it is on, those references are resolved
through `dynamic_var()`, which looks the name up freshly each time:

1. from a `DirConfig` `Variable` file, if one exists for that name;
2. otherwise from the [VariableDatabase](../config/VariableDatabase.md), unless
   [dynamic_variables_file_only](dynamic_variables_file_only.md) is also set;
3. otherwise from the in-memory `$::Variable` value.

This makes it possible to edit a variable's value in a file or database and have
the change take effect immediately on the next page view, without reconfiguring
the catalog.

## Examples

Enable dynamic variables catalog-wide. In `catalog.cfg`:

    Pragma dynamic_variables

Typically paired with a source directive, for example:

    VariableDatabase  variable
    Pragma            dynamic_variables

## Notes

This pragma only makes sense in combination with
[DirConfig](../config/DirConfig.md) or
[VariableDatabase](../config/VariableDatabase.md); on its own it adds per-request
lookup overhead with no new source of values.

To restrict dynamic lookups to files and skip the database entirely, also set
[dynamic_variables_file_only](dynamic_variables_file_only.md).

## See also

- [dynamic_variables_file_only](dynamic_variables_file_only.md)
- [DirConfig](../config/DirConfig.md)
- [VariableDatabase](../config/VariableDatabase.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `vars_and_comments()` (which
calls `dynamic_var()`) in `lib/Vend/Interpolate.pm`.
