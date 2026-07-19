# Route

Defines a named *order route* -- a set of keyed attributes describing one
way to process a submitted order (email it, log it, write it to tables,
hand it to a payment service, and so on). Reach for it to configure how
orders are finalized and to build multi-step routing with cascades.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Route  ROUTENAME  KEY  VALUE
    Route  ROUTENAME  <<EOF
        key   value
        key   value
    EOF

The first argument names the route; the rest sets one or more of its
attributes (`parse_locale`, the same keyed-hash mechanism used by
[Locale](Locale.md)). You may set attributes one per line as
`Route NAME KEY VALUE`, or supply many at once in a here-document of
`key value` pairs. Repeated lines for the same route accumulate into that
route's attribute hash. Default: empty.

## Description

Each `Route` builds a hash stored in the catalog's route repository under
the route's name. When an order is submitted, Interchange runs one or more
routes to complete it; the attributes of a route control what that step
does. Common attributes seen in the strap catalog include `email` and
`report` (where and how to mail the order), `track` and `individual_track`
(order logging), `supplant` (whether this route's result replaces the
default order handling), `empty` (clear the cart afterward),
`credit_card`/`encrypt` (payment handling), `write_tables` and
`transactions` (which tables the order is written to), and `cascade` (a
list of other routes to run in turn).

The special route `default` runs when no route is otherwise selected, and
by convention is defined last. A route marked `master 1` with a `cascade`
list orchestrates several sub-routes.

Routes are consumed in `lib/Vend/Order.pm` (order routing). Two attributes
change how a route's own values are resolved at run time: `dynamic_routes`
makes Interchange read the route's attributes from the table named by
[RouteDatabase](RouteDatabase.md), and `expandable` allows Interchange Tag
Language (ITL) inside route values to be interpolated.

## Examples

A simple logging route set with individual `Route NAME KEY VALUE` lines:

```
Route log  transactions  transactions
Route log  supplant      0
Route log  track         logs/log
```

The same route defined in a here-document (from the strap `catalog.cfg`):

```
Route log  <<EOF
    empty        1
    encrypt      0
    increment    0
    report       etc/log_transaction
    supplant     0
    track        logs/log
EOF
```

The `default` route cascading through several named routes:

```
Route   default   master    1
Route   default   cascade   "log main copy_user"
Route   default   supplant  1
Route   default   email     you@example.com
```

## Notes

The value syntax is shell-quoted, so multi-word values (such as a
`cascade` list) must be quoted. In the catalog directive tables this
directive is defined under the `locale` parser; that is only the parsing
mechanism -- routes are unrelated to internationalization locales.

## See also

[RouteDatabase](RouteDatabase.md), [OrderProfile](OrderProfile.md),
[OrderReport](OrderReport.md), [OrderCounter](OrderCounter.md), the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

## Source

Parsed by `parse_locale` in `lib/Vend/Config.pm` (stored in the catalog's
`Route_repository`); consumed in `lib/Vend/Order.pm`.
