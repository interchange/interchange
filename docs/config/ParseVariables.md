# ParseVariables

Controls whether configuration-directive values have their variable references
interpolated as the config file is read. Reach for it to embed
[Variable](Variable.md) values inside other directive lines.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ParseVariables  yesno

A boolean: `Yes`/`No`, `1`/`0`, `on`/`off`, `true`/`false` (case-insensitive).
Default: `No`.

## Description

While reading configuration, `lib/Vend/Config.pm` normally stores each directive
value verbatim. When `ParseVariables` is on, it first substitutes variable
references in the value -- both the `__NAME__` and `@@NAME@@` forms -- using the
catalog's already-defined variables. Only variables whose names are entirely
uppercase are interpolated. The [Variable](Variable.md) directive's own values
are not themselves reparsed this way.

The directive acts as a switch that you turn on and off around the lines that
need it: it takes effect for every directive parsed while it is `Yes`, so it is
usual to enable it, write the lines that reference variables, and turn it off
again. The strap demo enables it near the top of `catalog.cfg` so that path
directives can be built from variables.

## Examples

Enable substitution so a directory directive can be built from a variable (in
`catalog.cfg`):

```
Variable STORE_ID topshop

ParseVariables Yes
StaticDir /home/__STORE_ID__/www/cat
ParseVariables No
```

Here `StaticDir` is stored as `/home/topshop/www/cat`.

## See also

[Variable](Variable.md), [VarName](VarName.md), the
[configuration](../guides/configuration.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$C->{ParseVariables}` (through `substitute_variable`) in `lib/Vend/Config.pm`.
