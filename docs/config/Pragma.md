# Pragma

Sets the catalog-wide default value of an Interchange pragma -- a named
switch that alters page-parsing and interpolation behavior. Reach for it to
turn a behavior such as `dynamic_variables` or `strip_white` on (or off) for
every request in the catalog.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Pragma  name
    Pragma  name=value

Whitespace- or comma-separated `name` or `name=value` items, accumulated
into a hash. A bare `name` sets the pragma to `1`; `name=value` sets it to
the given value; `name=0` turns it off. Default: empty (each pragma uses
its built-in default).

## Description

A pragma is a per-request flag consulted while a page is parsed and
interpolated. `Pragma` seeds the catalog's default set: the parsed hash is
stored in `$Vend::Cfg->{Pragma}` and copied into the request-scoped
`$::Pragma` hash at the start of each request (in `lib/Vend/Dispatch.pm`).
Individual pages can then override a pragma for their own duration with the
[pragma](../tags/pragma.md) tag.

Because the value is a free-form string, a pragma can carry data as well as
a boolean -- for example `init_page=myRoutine` names a routine rather than
just enabling a feature. See the [pragmas reference](../pragmas/) for the
full list of recognized names and their meanings.

## Examples

Enable dynamic variable interpolation (in `catalog.cfg`):

```
Pragma dynamic_variables
```

Explicitly disable a pragma:

```
Pragma dynamic_variables=0
```

Set a pragma to a specific value:

```
Pragma init_page=myInitRoutine
```

Several pragmas from the strap demo catalog:

```
Pragma dynamic_variables
Pragma dynamic_variables_file_only
Pragma strip_white
```

## See also

[pragma](../tags/pragma.md) tag, the [pragmas reference](../pragmas/),
[ParseVariables](ParseVariables.md), the
[templating](../guides/templating.md) guide.

## Source

Parsed by `parse_boolean_value` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{Pragma}` and the request-scoped `$::Pragma` hash in
`lib/Vend/Dispatch.pm` and throughout the interpolation code.
