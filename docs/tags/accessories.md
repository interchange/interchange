# accessories

Build a form widget (dropdown, radio group, checkbox set, text box, and so on)
for a product's options or attributes. Reach for it on a flypage or basket line
when you need a "choose size / color" control tied to a product code.

## Syntax

    [accessories code arg]
    [accessories code=SKU attribute=color type=select ...]

Standalone tag (no end tag). The return value is HTML for a form widget; it is
not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute   | Default | Description |
|-------------|---------|-------------|
| `code`      | none    | Product SKU whose option value is looked up. When empty, no database lookup happens and the widget is built entirely from the options you pass. |
| `arg`       | none    | Comma-separated shorthand that fills, in order, `attribute`, `type`, `column`, `table`, `name`, `outboard`, `passed`. |
| `attribute` | none    | The option name (for example `size` or `color`). Used as the form field name unless `name` is given. |
| `type`      | `select` | Widget type: `select`, `radio`, `checkbox`, `text`, `password`, `hidden`, and the other types the form-widget engine understands. |
| `column`    | value of `attribute` | Database column read for the option string. |
| `table`     | `products` | Table read for the option string (defaults to the products database when unset). |
| `name`      | value of `attribute` | HTML field name emitted for the widget. |
| `outboard`  | value of `code` | Key used for the lookup when it differs from `code`. |
| `passed`    | looked up | The option definition string itself; supply it to skip the database read entirely. |

Positional order: `code`, `arg`.

Aliases: `db`, `base`, `database` for `table`; `col`, `field` for `column`;
`row`, `key` for `code`.

Because the tag declares `addAttr`, any other attribute (for example
`default`, `label`, or widget-specific options) is forwarded to the
form-widget builder.

## Description

`[accessories]` is a thin front end to `Vend::Form::display`, the same routine
that renders form widgets throughout Interchange. Its job is to obtain an
*option definition string* and hand it, along with your options, to that
builder.

When you supply `code`, the tag reads column `column` (or, absent that,
`attribute`) for that key: from `table` if given, otherwise from the products
database via `product_field`. The looked-up string becomes `passed`. If neither
a value nor an explicit `type` is available, the tag returns nothing; input
types (`text`, `password`, `hidden`) are allowed to render with no stored
definition.

An option definition string encodes the choices for the widget, for example a
`select` list of `value=label` pairs. The exact grammar (multiple values,
labels, default markers) is the form-widget engine's; see
[forms](../guides/forms.md).

The comma shorthand `arg` exists so a single positional argument can carry the
whole configuration, which is handy inside loops. `[accessories 00-0011
color,radio]` is equivalent to
`[accessories code=00-0011 attribute=color type=radio]`.

## Examples

Render the default (`select`) widget for the `size` option of a product,
reading the definition from the products table:

    [accessories code=00-0011 attribute=size]

Same option as a radio-button group:

    [accessories code=00-0011 attribute=size type=radio]

Supply the option string directly, without any database lookup:

    [accessories attribute=color type=select passed="red=Red,grn=Green,blu=Blue"]

Positional shorthand inside an item list, taking the code from the current
line item:

    [item-list]
      [accessories [item-code] color,select]
    [/item-list]

## Notes

The richer product-options system (matrix, modular, and simple options)
supersedes plain accessories for most catalogs; see the
[options](options.md) tag. `[accessories]` remains the low-level way to render
a single option widget from an arbitrary column.

The set of option types and the definition-string grammar are defined by
`Vend::Form`; this page does not restate them.

## See also

- [options](options.md)
- [item-list](item-list.md)
- [data](data.md), [field](field.md)
- Concepts: [forms](../guides/forms.md)

## Source

Defined in `code/SystemTag/accessories.coretag`. Implemented by
`Vend::Interpolate::tag_accessories`, which delegates to `Vend::Form::display`.
