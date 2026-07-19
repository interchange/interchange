# OptionsEnable

Turns on Interchange's item-options subsystem and names the table and/or column
that says which option type a product uses. Reach for it to give products
matrix, simple, or custom options (size, color, and the like).

**Scope:** catalog (`catalog.cfg`)

## Syntax

    OptionsEnable  column
    OptionsEnable  table:column
    OptionsEnable  attribute=table:column

The value is stored as-is (no parser) and split on colons at use time. With a
bare `column`, the option type is read from that column of the item's own
product table. With `table:column`, the type is read from `column` of `table`.
The `attribute=` prefix additionally names the item attribute under which the
looked-up type is cached. Default: empty (options disabled).

## Description

When `OptionsEnable` is set, `lib/Vend/Options.pm` determines each item's option
type at order and display time. It splits the value into a table and field,
looks up the option type for the item's SKU, and stores it in the item attribute
named by [OptionsAttribute](OptionsAttribute.md) (defaulting to the field name
if that directive is unset). The resulting type selects an option module --
`Simple`, `Matrix`, `Old48`, or a custom type registered through the
[Options](Options.md) directive.

At configuration time, setting `OptionsEnable` also causes the named column to be
treated as an auto-modifier so its value is carried on each cart line.

## Examples

Read each product's option type from an `option_type` column in its own table --
the strap demo's setting (in `catalog.cfg`):

```
OptionsEnable option_type
```

Read the type from a dedicated `options` table instead:

```
OptionsEnable options:o_type
```

## See also

[Options](Options.md), [OptionsAttribute](OptionsAttribute.md),
[UseModifier](UseModifier.md), [AutoModifier](AutoModifier.md), the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

## Source

Parsed with no parser (raw string) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{OptionsEnable}` in `lib/Vend/Options.pm` (with configuration-time
handling in `lib/Vend/Config.pm`).
