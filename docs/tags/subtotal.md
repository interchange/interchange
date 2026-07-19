# subtotal

Return the subtotal of the products in a shopping cart — the sum of item
prices before shipping, handling, and tax. Reach for it on basket and checkout
pages to show the cost of the goods.

## Syntax

    [subtotal]
    [subtotal cart=NAME noformat=1 nodiscount=1]

Standalone tag (no end tag). Returns the amount formatted as currency by
default.

## Attributes

| Attribute        | Default  | Description |
|------------------|----------|-------------|
| `name`           | `main`   | Name of the cart to total. |
| `noformat`       | `0`      | When true, return the raw number instead of a currency-formatted string. |
| `discount_space` |          | Discount "space" (namespace) whose discounts apply to the calculation. |
| `nodiscount`     | `0`      | When true, ignore discounts and total the undiscounted item prices. |

Positional order: `name`, `noformat` (`PosNumber 2`).

Alias: `cart` for `name`. Alias: `space` for `discount_space`.

Additional named attributes are passed through to the currency formatter, so
locale/format options accepted by [currency](currency.md) (such as `locale`)
also work here.

## Description

The tag calls the internal `subtotal` routine for the named cart within the
given discount space, then formats the result with `currency`. Any discounts
registered with [discount](discount.md) are applied unless `nodiscount` is
set. Setting `noformat` returns the bare numeric value, which is what you want
when feeding the amount into further calculation or into a log.

The subtotal covers item prices only; it does not include shipping
([shipping](shipping.md)), handling ([handling](handling.md)), or sales tax
([salestax](salestax.md)). For the fully adjusted order total use
[total-cost](total-cost.md).

## Examples

Show the formatted subtotal on a basket page:

    Subtotal: [subtotal]

produces, for a cart of goods worth 49.90 with a `$` currency symbol:

    Subtotal: $49.90

Get the raw number for use in a calculation:

    [tmp raw_sub][subtotal noformat=1][/tmp]

Total the goods ignoring any active discounts:

    [subtotal nodiscount=1]

## See also

[total-cost](total-cost.md), [currency](currency.md),
[nitems](nitems.md), [item-list](item-list.md), [discount](discount.md),
the [pricing](../guides/pricing.md) and
[cart-and-checkout](../guides/cart-and-checkout.md) guides.

## Source

Defined in `code/SystemTag/subtotal.coretag` as an inline `Routine` that wraps
`Vend::Interpolate::subtotal` and `Vend::Util::currency`.
