# var

Return the value of a catalog (or global) configuration Variable, with an
optional filter. Reach for `[var NAME]` when you need a Variable's value
computed at run time — inside another tag's attributes, or when the target name
is itself dynamic — rather than the compile-time `__NAME__` / `@_NAME_@`
substitutions.

## Syntax

    [var NAME]
    [var NAME global]
    [var NAME 2 filtername]

Standalone tag (no end tag). Its output is interpolated (`Interpolate 1`).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    |         | Variable name to read (positional 1). |
| `global`  | `0`     | Which scope to read: false = catalog; `1` = global; `2` = catalog, falling back to global (positional 2). |
| `filter`  |         | A [filter](../filters/) (or space-separated list) applied to the value (positional 3). |

Positional order: `name`, `global`, `filter`.

## Description

Interchange has two Variable scopes: **catalog** Variables
(`Variable` directives in `catalog.cfg`, held in `$Variable`) and **global**
Variables (`Variable` in `interchange.cfg`, held in `$Global::Variable`).
`[var NAME]` reads the catalog Variable `NAME`. The `global` argument selects a
different resolution:

- falsey (default): return the catalog Variable.
- `1`: return the global Variable directly.
- `2`: return the catalog Variable, but fall back to the global one if the
  catalog value is empty.

Two behaviors layer on top of the basic lookup:

- **Member override.** If the session is logged in and the account
  (`$Cfg->{Member}`) defines `NAME`, that member value is returned instead —
  letting a logged-in user carry per-account overrides of catalog Variables.
- **Dynamic variables.** When the `dynamic_variables` pragma is on, the catalog
  lookup goes through `dynamic_var`, which can resolve the value from a
  database-backed variable table rather than the static config.

`filter` runs the resulting value through the named filter(s) before returning.

### `[var]` versus `__NAME__` and `@_NAME_@`

The plain substitutions `__NAME__` (catalog) and `@_NAME_@` (global) are
replaced when the page is first parsed and cannot take a computed name or a
filter. `[var ...]` is the tag form: it is evaluated as a tag at run time, so
you can nest it, filter its output, choose the scope with `global`, and (with
the pragma) resolve dynamic values. Use the substitutions for simple static
insertion and `[var]` when you need any of that flexibility.

## Examples

Read a catalog Variable:

    [var COMPANY]

Read a global Variable — the strap templates do this for the current page path:

    [var MV_PAGE global]

Catalog value with a global fallback:

    [var LOGO 2]

Filter the value on the way out:

    [var COMPANY 0 lower]

Use it where a compile-time substitution cannot go — a computed name:

    [var [scratch which_banner]]

## Notes

- A logged-in session with a matching `Member` key shadows the catalog
  Variable; if a value unexpectedly differs by user, check the member record.
- `global=2` only falls back to the global value when the catalog value is
  false (empty or `0`), not merely undefined.

## See also

- [config](config.md) — read configuration *directives* (not Variables)
- [value](value.md) — read session form values
- The [variables reference](../variables/) and
  [configuration guide](../guides/configuration.md)

## Source

Defined in `code/UserTag/var.tag` (inline `Routine`).
