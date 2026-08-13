# PageSelectField

Names a `products` column that chooses which flypage template renders a given
product. Reach for it when different products need different on-the-fly display
pages.

**Scope:** catalog (`catalog.cfg`)

A flypage is the template Interchange renders on the fly to display a single
product that has no dedicated page of its own.

## Syntax

    PageSelectField  column

A single database column name, stored as-is (no parser). Default: empty (the
standard `flypage` template is used for every product).

## Description

When Interchange builds a product's flypage, `lib/Vend/Interpolate.pm` looks at
`PageSelectField`. If the directive names a column that exists in the product's
table, the value of that column for the product becomes the template name:

```perl
elsif( $selector = $Vend::Cfg->{PageSelectField}
       and db_column_exists($base,$selector) )
{
    $selector = database_field($base, $code, $selector)
}
```

If the column is empty for a given product (no whitespace), or the directive is
unset, Interchange falls back to the special `flypage` page. This lets you
maintain several flypage layouts and pick one per product by storing its name in
the chosen column.

## Examples

Select the flypage from a `display_page` column (in `catalog.cfg`):

```
PageSelectField display_page
```

A product whose `display_page` value is `books_flypage` then renders through the
`books_flypage` template; a product with an empty `display_page` renders through
the standard `flypage`.

## See also

[PageDir](PageDir.md), [SpecialPage](SpecialPage.md), the
[templating](../guides/templating.md) guide.

## Source

Parsed with no parser (raw string) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{PageSelectField}` in `lib/Vend/Interpolate.pm`.
