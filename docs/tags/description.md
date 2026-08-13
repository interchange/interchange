# description

Returns the description of a product from the products database. It looks up
the configured description column for a SKU, searching every products table
unless you name one. Reach for it whenever you have a product code and need its
human-readable name outside a loop.

## Syntax

    [description code]
    [description code base]
    [description code=sku base=table]

Standalone tag (no end tag).

## Attributes

| Attribute | Default              | Description |
|-----------|----------------------|-------------|
| `code`    | (none)               | Product SKU to look up. |
| `base`    | all `ProductFiles`   | Products table to search. |

Positional order: `code`, `base`.

## Description

The tag maps to `Vend::Data::product_description`. It returns the value of the
column named by the `DescriptionField` catalog directive (by default
`description`) for the given SKU. If `base` is omitted, Interchange searches the
tables listed in the `ProductFiles` directive, in order, and returns the
description from the first table that contains the code. If the SKU is not found
in any products table, the tag returns an empty string.

`description` is a convenience wrapper: it always reads the `DescriptionField`
column of a products table. To read any other column, or a column from a
non-products table, use [field](field.md) or [data](data.md). Inside a
[loop](loop.md) or [item-list](item-list.md), the per-row sub-tag
`[PREFIX-description]` gives the same value for the current row.

## Examples

With the strap demo `products` table, show the description of one SKU:

    [description os28004]

produces (for the demo data):

    Ergo Roller

Use the named-attribute form and pin the lookup to a specific table:

    [description code="[cgi sku]" base=products]

## See also

- [field](field.md), [data](data.md) — read arbitrary product columns
- [price](price.md) — companion tag for the product price
- `DescriptionField`, `ProductFiles` (see [../config/](../config/))
- Guide: [Databases](../guides/databases.md)

## Source

Defined in `code/SystemTag/description.coretag`. Implemented by
`Vend::Data::product_description` in `lib/Vend/Data.pm`.
