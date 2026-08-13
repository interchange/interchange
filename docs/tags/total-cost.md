# total-cost

Return the grand total of a shopping cart — item subtotal plus all
adjustments (quantity pricing, discounts, handling, shipping, and tax). Reach
for it to show the final amount the customer will pay.

## Syntax

    [total-cost]
    [total-cost cart=NAME noformat=1]

Standalone tag (no end tag). Returns the amount formatted as currency by
default.

## Attributes

| Attribute        | Default | Description |
|------------------|---------|-------------|
| `name`           | `main`  | Name of the cart to total. |
| `noformat`       | `0`     | When true, return the raw number instead of a currency-formatted string. |
| `discount_space` |         | Discount "space" (namespace) whose discounts apply. |

Positional order: `name`, `noformat` (`PosNumber 2`).

Alias: `cart` for `name`. Alias: `space` for `discount_space`.

Additional named attributes pass through to the currency formatter, so options
accepted by [currency](currency.md) (such as `locale`) work here too.

## Description

The tag calls the internal `total_cost` routine for the named cart and discount
space, then formats the result with `currency` unless `noformat` is set. The
total includes the item [subtotal](subtotal.md) with all price adjustments and
discounts, plus [handling](handling.md), [shipping](shipping.md), and
[salestax](salestax.md).

Shipping and handling are only added when their controlling values
(`mv_shipmode` and `mv_handling`) are set. If you supply those amounts with
[assign](assign.md) and provide no defaults, an empty value leaves that
component out of the total.

## Examples

Show the order total on a receipt:

    Total: [total-cost]

produces, for an order of $49.90 goods + $5.00 shipping:

    Total: $54.90

Get the raw number to store or compare:

    [tmp order_total][total-cost noformat=1][/tmp]

## See also

[subtotal](subtotal.md), [currency](currency.md), [salestax](salestax.md),
[shipping](shipping.md), [handling](handling.md), [assign](assign.md),
the [cart-and-checkout](../guides/cart-and-checkout.md) and
[pricing](../guides/pricing.md) guides.

## Source

Defined in `code/SystemTag/total_cost.coretag` as an inline `Routine` that
wraps `Vend::Interpolate::total_cost` and `Vend::Util::currency`.
