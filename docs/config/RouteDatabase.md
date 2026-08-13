# RouteDatabase

Names a database table from which order-route attributes can be read at run
time, so routes may be maintained as data rather than only in `catalog.cfg`.
Reach for it when you want dynamic order routing driven by a table.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    RouteDatabase  dbname  file  type

A `parse_configdb` value naming a table: an identifier, its source file,
and its table type (for example `dbi:mysql:routes`, `TAB`, or `CSV`).
Default: empty.

## Description

`RouteDatabase` does two things. At configuration time its parser reads the
named table's rows into the catalog's route repository, so routes defined
as table rows become available as named [Route](Route.md) definitions.
Interchange also retains the table name so it can re-read a route live: when
a route is run with the `dynamic_routes` attribute set, Interchange looks up
a row keyed by the route name in the `RouteDatabase` table and uses that
row's columns as the route's attributes, overriding the values from
`catalog.cfg` (a few keys, such as the encryption program, are preserved
from the static definition). This lets you change routing behavior by
editing table data.

The configuration-time load is performed by the parser in
`lib/Vend/Config.pm`; the per-order dynamic lookup is performed in
`lib/Vend/Order.pm`, only for routes flagged `dynamic_routes`.

## Examples

Point at a `route` table and enable dynamic lookup for the `default` route
(in `catalog.cfg`):

```
RouteDatabase route route.txt dbi:mysql:route
Route default dynamic_routes 1
```

At order time, the attributes of the `default` route are read from the
`route` table's row whose key is `default`.

## Notes

Only routes that set `dynamic_routes 1` consult this table; routes without
that attribute use their statically configured values. The table's column
names correspond to route attribute names.

## See also

[Route](Route.md), [ConfigDatabase](ConfigDatabase.md),
[DirectiveDatabase](DirectiveDatabase.md), the
[databases](../guides/databases.md) and
[cart-and-checkout](../guides/cart-and-checkout.md) guides.

## Source

Parsed by `parse_configdb` in `lib/Vend/Config.pm`; consumed per order in
`lib/Vend/Order.pm`.
