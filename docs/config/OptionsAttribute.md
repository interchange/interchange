# OptionsAttribute

Names the cart-line attribute that records which option type an item uses. Reach
for it when you want the option type held under a specific attribute name rather
than the field name Interchange derives from
[OptionsEnable](OptionsEnable.md).

**Scope:** catalog (`catalog.cfg`)

## Syntax

    OptionsAttribute  attribute

A single item-attribute name, stored as-is (no parser). Default: empty. When
unset, Interchange falls back to the field name taken from
[OptionsEnable](OptionsEnable.md).

## Description

The item-options subsystem in `lib/Vend/Options.pm` decides each item's option
type. `OptionsAttribute` names the attribute on the cart line that caches that
type. When `find_options_type` runs, it first honors an already-set
`OptionsAttribute` value on the item:

```perl
return $item->{$attrib}
    if $attrib = $Vend::Cfg->{OptionsAttribute}
    and defined $item->{$attrib};
```

If `OptionsAttribute` is not configured, the subsystem sets it implicitly from
the field named by [OptionsEnable](OptionsEnable.md). You usually only set it
explicitly when the attribute and the source column should have different names,
or when you set the attribute directly on an item (for example through an
on-the-fly order) and want Interchange to trust it.

## Examples

Cache the option type under an `otype` attribute (in `catalog.cfg`):

```
OptionsEnable option_type
OptionsAttribute otype
```

## See also

[OptionsEnable](OptionsEnable.md), [Options](Options.md),
[UseModifier](UseModifier.md), the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

## Source

Parsed with no parser (raw string) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{OptionsAttribute}` in `lib/Vend/Options.pm` and
`lib/Vend/Order.pm`.
