# price

Return the price of a product, formatted as currency in the catalog's locale.
Reach for it to display a catalog price on a page or in a listing, optionally
for a specific quantity, with quantity price breaks and discounts applied.

## Syntax

    [price code]
    [price code="sku" quantity="10" discount=1 noformat=1]

Standalone tag (no end tag). Returns a formatted currency string by default.

## Attributes

| Attribute   | Default | Description |
|-------------|---------|-------------|
| `code`      | (required) | Product SKU whose price to return. |
| `quantity`  | 1       | Quantity to price, so quantity price breaks apply. |
| `discount`  | off     | If true, apply the current cart discounts to the price. |
| `noformat`  | off     | Return the raw number without currency formatting. |
| `base`      | (auto)  | Products table to read from. |
| `space`     | (main)  | Discount space to price within. |

Positional order: `code`.
Alias: `base` for `mv_ib` (the products table/database).
Alias: `space` for `discount_space`.

## Description

`price` looks up the price of `code` through `Vend::Data::item_price`, which
honors the catalog's pricing rules: the `CommonAdjust`/`PriceField` setup,
quantity price breaks (the price can change with `quantity`), and per-item
modifiers. The result is passed through `currency`, so it comes back formatted
according to the active locale (currency symbol, decimal and thousands
separators) — for example `$10.00`.

Two behaviors are opt-in:

- `discount=1` runs the returned amount through `discount_price`, applying any
  discounts currently active in the cart. Without it, the undiscounted catalog
  price is returned.
- `noformat=1` skips currency formatting and returns the bare number, useful
  when you need to feed the value into a calculation.

The `space` attribute selects a discount space (a named set of discounts),
switching to it for the duration of the lookup and restoring the previous space
afterward.

## Examples

Show the price of a single item (strap demo sku `os28004`):

    [price os28004]

produces (with the default locale):

    $10.00

Price ten of an item so quantity breaks apply:

    [price code=os28004 quantity=10]

Apply active cart discounts:

    [price code=os28004 discount=1]

Get the unformatted number for use in a calculation:

    [calc][price code=os28004 noformat=1] * 1.0825[/calc]

From a loop, price each row's item at the row's quantity (as the strap
`quantity` page does):

    [order code="[part-code]" quantity="[loop-code]"][price code="[part-code]" quantity="[loop-code]"]</a>

## Notes

- `price` reads the catalog price of a product code. To show the price of an
  item already in the cart at its cart quantity, use the cart's own
  `[item-price]` loop subtag instead.
- Formatting follows the current locale; switching locale changes the currency
  symbol and separators.

## See also

- [currency](currency.md) — format an arbitrary number as currency
- [field](field.md) / [data](data.md) — read other product columns
- [order](order.md) — order-this-item link
- [discount](discount.md), [PriceDefault](../config/PriceDefault.md)
- [pricing guide](../guides/pricing.md)

## Source

Defined in `code/SystemTag/price.coretag`. Implemented by the inline `Routine`
in that file, which calls `Vend::Data::item_price`, optionally
`discount_price`, and `Vend::Interpolate::currency`.
