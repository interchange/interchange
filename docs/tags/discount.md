# discount

Set (or clear) a per-item discount formula in the shopper's session. The
formula is a Perl expression that Interchange evaluates against each
matching cart item when it totals the order, so reach for `[discount]`
when you need coupon logic, quantity breaks, or any price adjustment that
must survive across pages.

## Syntax

    [discount CODE] FORMULA [/discount]
    [discount code=CODE subtract=N] [/discount]

`[discount]` is a container tag: its body is the discount formula. The
body is stored verbatim (it is not interpolated as Interchange Tag
Language, ITL — it is later run as Perl), so you normally write plain
Perl in it. An empty body clears the discount for `CODE`.

## Attributes

| Attribute  | Default | Description |
|------------|---------|-------------|
| `code`     | (none)  | Item code the discount applies to; positional parameter 1. Two special codes exist (see below). |
| `subtract` | (none)  | Convenience: generate a formula that subtracts this amount from the item price, floored at zero. |
| `level`    | (none)  | Convenience: generate a quantity-break formula that discounts once quantity reaches this level. |
| `space`    | (none)  | Discount namespace (discount space) to store the formula in, when `DiscountSpacesOn` is set. Alias for `discount_space`. |

Positional order: `code`.

Alias: `space` for `discount_space`.

## Description

Interchange keeps discounts in a per-session hash. Each key is an item
code and each value is a Perl expression. When the cart is totaled, the
expression for a given item is evaluated in a `Safe` compartment with
these variables available:

- `$s` — the current price of the item (the subtotal being adjusted).
- `$q` — the quantity of the item.
- `$item` — the cart item hash reference.

The expression must return the new price. For example, a body of
`$s * 0.9` gives 10% off, and `$s - 5` takes five units of currency off.

Two item codes are special:

- `ALL_ITEMS` — the formula is applied to every item in the cart, in
  addition to any item-specific discount.
- `ENTIRE_ORDER` — the formula is applied once to the whole taxable
  subtotal rather than per item. Here `$s` is the running subtotal and
  `$q` is the total number of items.

The `subtract` and `level` options write the formula for you instead of
requiring you to type Perl:

- `subtract=N` stores a formula equivalent to
  `my $tmp = $s - N; $tmp = 0 if $tmp < 0; return $tmp;`
- `level=N` stores a quantity-break formula: the item is charged at the
  full `$s * $q` until quantity reaches `N`, after which one unit becomes
  effectively free (`$s - $s/$q`).

Discounts are stored per session and persist until you clear them (an
empty body) or the session ends. To use parallel discount namespaces
alongside multiple carts, enable the
[DiscountSpacesOn](../config/DiscountSpacesOn.md) directive and select a
space with the `space` attribute or the
[discount_space](discount_space.md) tag.

## Examples

Take 10% off item `os28004` whenever it is in the cart:

    [discount os28004]$s * 0.9[/discount]

Give every item five currency units off, floored at zero, using the
`subtract` convenience option:

    [discount code=ALL_ITEMS subtract=5][/discount]

Apply an order-wide coupon amount held in scratch (as the strap demo
does), discounting the entire order subtotal:

    [discount ENTIRE_ORDER] $s - $Scratch->{coupon_amount}; [/discount]

Clear the discount for `os28004` by passing an empty body:

    [discount os28004][/discount]

## Notes

The body is Perl run in a `Safe` compartment, not ITL. A malformed
formula is logged as a "Bad discount code" error and the item falls back
to its undiscounted price. Because the stored value is code, only set
discounts from trusted pages, never from raw user input.

## See also

[discount_space](discount_space.md),
[DiscountSpacesOn](../config/DiscountSpacesOn.md),
[fly-tax](fly-tax.md), the [pricing](../guides/pricing.md) and
[cart and checkout](../guides/cart-and-checkout.md) guides.

## Source

Defined in `code/SystemTag/discount.coretag` (inline `Routine`). The
stored formulas are evaluated by `Vend::Interpolate::discount_price` and,
for `ENTIRE_ORDER`, in the subtotal routines of `lib/Vend/Interpolate.pm`.
