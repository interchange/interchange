# OnFly

Enables "on-the-fly" additions to the shopping cart -- items that are built from
form data at add time instead of being looked up in a product table. Reach for
it when you sell made-to-order or dynamically priced items that have no fixed
`products` row.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    OnFly  1
    OnFly  tagname

The value is stored as-is (no parser). Set it to a true value such as `1` to
enable on-the-fly ordering using the built-in
[onfly](../tags/onfly.md) tag, or to the name of an Interchange Tag Language
(ITL) tag to use your own formatter. Default: empty (disabled).

## Description

When `OnFly` is set and a request carries an `mv_order_fly` value, Interchange
builds the cart line from the submitted data rather than from a product record.
`lib/Vend/Order.pm` invokes the named tag to produce each item:

```perl
$item = Vend::Parse::do_tag($Vend::Cfg->{OnFly},
    $code,
    $quantity,
    $fly[$j],
);
```

The tag is therefore called with the item code, the quantity, and the item's
`mv_order_fly` value. Setting `OnFly 1` uses the shipped
[onfly](../tags/onfly.md) tag, which understands a compact field syntax for
description and price. Setting `OnFly mytag` substitutes a
[UserTag](UserTag.md) of your own; use the shipped `onfly` tag as a model.

## Examples

Enable on-the-fly ordering with the built-in tag (in `catalog.cfg`):

```
OnFly 1
```

Use a custom formatter tag instead:

```
OnFly my_onfly_tag
```

## Notes

The submitted price and description travel with the request, so an on-the-fly
item's price is client-supplied unless your tag recomputes or validates it.
Treat the incoming values as untrusted when writing a custom tag.

## See also

[onfly](../tags/onfly.md), [UserTag](UserTag.md), the
[cart-and-checkout](../guides/cart-and-checkout.md) and
[pricing](../guides/pricing.md) guides.

## Source

Parsed with no parser (raw string) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{OnFly}` in `lib/Vend/Order.pm` and `lib/Vend/Data.pm`.
