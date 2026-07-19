# field

Return a single column value for a product SKU from the catalog's product
database(s). It is the quick way to pull a field such as `description`,
`price`, or `weight` for a known item code.

## Syntax

    [field COLUMN CODE]
    [field name=COLUMN code=CODE]

Standalone tag. Returns the field value as plain text, or an empty string
if the SKU or column is not found.

## Attributes

| Attribute | Default    | Description |
|-----------|------------|-------------|
| `name`    | (required) | Column (field) name to retrieve; positional parameter 1. |
| `code`    | (required) | Product code (SKU) to look up; positional parameter 2. |

Positional order: `name`, `code`.

Aliases: `column`, `col`, and `field` for `name`; `row` and `key` for
`code`.

## Description

`[field]` searches the tables listed in the
[ProductFiles](../config/ProductFiles.md) directive — the catalog's
product databases — and returns the named column from the first table in
which the SKU exists. If the SKU is not found in any product table, or the
column does not exist, it returns an empty string.

Because it walks all product tables in order, `[field]` is the right tag
when a catalog spreads its products across several product files. When you
need a value from a specific, arbitrary table instead, use the more general
[data](data.md) tag, which names the table explicitly.

## Examples

Get the description for SKU `os28004`:

    [field description os28004]

Show the price of the current flypage item:

    Price: [field price [item-code]]

Named form, equivalent to the first example:

    [field name=description code=os28004]

## Notes

With a single products table, `[field column key]` is equivalent to
`[data products column key]`; the difference only matters when
[ProductFiles](../config/ProductFiles.md) lists more than one table, where
`[field]` returns the first match across them all.

## See also

[data](data.md), [description](description.md), [price](price.md),
[ProductFiles](../config/ProductFiles.md), the
[databases](../guides/databases.md) guide.

## Source

Defined in `code/SystemTag/field.coretag`, mapped to
`Vend::Data::product_field` in `lib/Vend/Data.pm`.
