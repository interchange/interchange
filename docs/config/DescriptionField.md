# DescriptionField

Names the products-table column that holds a product's description. Reach
for it when your product description lives in a column named something
other than `description`, or when you want a locale-specific description
field.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    DescriptionField  field_name

A raw string (no parser): the column name. Default: `description`.

## Description

Several parts of Interchange look up a product's description without you
naming the column each time -- for example the `[item-description]` tag in
a cart or order loop, and `product_description` lookups in
`lib/Vend/Data.pm`:

```perl
return database_field($base, $code, $Vend::Cfg->{DescriptionField});
```

`DescriptionField` tells those lookups which column to read. Change it to
match your schema, or set it per locale so descriptions vary by language.

## Examples

Point description lookups at a `dsc` column:

```
DescriptionField dsc
```

Use a locale-specific description column for French, keeping the default
for everyone else:

```
# Default description field
DescriptionField    description

# French locale uses a translated column
Locale fr_FR  DescriptionField  desc_fr
```

## Notes

The field is read implicitly by description-oriented tags, so changing it
affects everywhere a product description is shown. Related field-name
directives ([PriceField](PriceField.md),
[CategoryField](CategoryField.md)) follow the same pattern.

## See also

[PriceField](PriceField.md), [CategoryField](CategoryField.md),
[Locale](Locale.md), the [databases](../guides/databases.md) and
[internationalization](../guides/internationalization.md) guides.

## Source

Stored unparsed in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{DescriptionField}` in `lib/Vend/Data.pm`.
