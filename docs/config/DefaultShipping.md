# DefaultShipping

Sets the shipping mode a new session starts with, by initializing the
`mv_shipmode` value. Reach for it to change which shipping method is
pre-selected before the shopper chooses one.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    DefaultShipping  ship_mode

A raw string (no parser): the name of a shipping mode. Default: `default`.

## Description

When a session is created, Interchange seeds the shopper's `mv_shipmode`
value from this directive:

```perl
$::Values->{mv_shipmode} = $Vend::Cfg->{DefaultShipping}
```

so the named mode is the initial shipping selection until a form or page
sets `mv_shipmode` to something else. The shipping mode named here should
be one defined in your shipping configuration (see
[Shipping](Shipping.md) and the shipping table).

## Examples

Start sessions with the `UPS` shipping mode selected:

```
DefaultShipping UPS
```

## Notes

This directive is largely a convenience: the same effect is available with
`ValuesDefault mv_shipmode UPS`, which initializes the same value through
the general defaults mechanism. Either approach only sets the *initial*
value; the shopper's choice overrides it.

## See also

[CustomShipping](CustomShipping.md), [Shipping](Shipping.md),
[ValuesDefault](ValuesDefault.md), the [shipping](../guides/shipping.md)
guide.

## Source

Stored unparsed in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{DefaultShipping}` in `lib/Vend/Session.pm`.
