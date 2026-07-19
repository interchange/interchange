# CategoryField

Names the database column that holds a product's category. Reach for it when
your products table stores the category under a name other than the default
`category`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    CategoryField  field_name

A single database field (column) name. Default: `category`.

## Description

When Interchange needs a product's category -- for example through the
[category](../tags/category.md) helper or user tracking -- it reads the column
named by `CategoryField` from the products table. Setting this directive lets a
catalog whose schema calls the column something else point Interchange at the
right field.

The value can also be varied per locale through the [Locale](Locale.md)
directive, so different locales can draw the category from different columns.

## Examples

Use a `type` column instead of `category` (in `catalog.cfg`):

```
CategoryField type
```

## See also

[DescriptionField](DescriptionField.md), [PriceField](PriceField.md),
[Locale](Locale.md), the [databases](../guides/databases.md) guide.

## Source

Parsed with no parser (raw string) in `lib/Vend/Config.pm`; consumed by
`category_name` and related lookups in `lib/Vend/Data.pm` and
`lib/Vend/Track.pm`.
