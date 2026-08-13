# assign

Store fixed numeric overrides for the sales-tax, shipping, handling, subtotal,
and credit amounts in the session, so those values are used verbatim instead of
being calculated. Reach for it when a checkout flow needs to force a specific
amount (a negotiated shipping rate, a flat tax, a manual credit).

## Syntax

    [assign shipping=4.99]
    [assign salestax=0 handling=2.50]
    [assign clear=1]

Standalone tag (no end tag). It produces no output; it only mutates the
session.

## Attributes

| Attribute  | Default | Description |
|------------|---------|-------------|
| `salestax` | none    | Fixed override for [salestax](salestax.md). Used as-is (no rounding). |
| `shipping` | none    | Fixed override for [shipping](shipping.md). Rounded to the locale's fractional digits. |
| `handling` | none    | Fixed override for [handling](handling.md). Rounded to the locale's fractional digits. |
| `subtotal` | none    | Fixed override for [subtotal](subtotal.md). Used as-is (no rounding). |
| `credit`   | none    | A credit amount recorded in the session's assignment set. |
| `clear`    | `0`     | When true, remove *all* assignments and do nothing else. |

Positional order: none (`PosNumber` is 0) — always call `[assign]` with named
attributes.

## Description

`[assign]` writes into `$Vend::Session->{assigned}`, the hash the ordering tags
consult for override values. The keys it accepts are exactly `salestax`,
`shipping`, `handling`, `subtotal`, and `credit`; any other attribute is
ignored.

For each recognized key, the value is trimmed of surrounding whitespace and
must match a signed decimal number (`-?\d+\.?\d*`). Negative numbers are
allowed. A valid number is stored; an *empty string* deletes that single
assignment. Any other non-numeric value is rejected: the assignment for that
key is deleted and an error is logged (`Attempted assign of non-numeric ...`).

Assignments persist for the life of the session until you overwrite or clear
them. `clear=1` deletes the whole `assigned` hash at once.

Two subtleties matter:

- `handling=0` sets handling to zero — it does **not** clear the override. To
  remove an override, assign an empty string (`handling=""`).
- You cannot assign a total cost directly; [total-cost](total-cost.md) is
  always the sum of the component amounts (with the overrides applied).

## Examples

Force a flat shipping charge:

    [assign shipping=4.99]

Set handling to exactly zero:

    [assign handling=0]

Clear only the sales-tax override, letting it be calculated again:

    [assign salestax=""]

Clear every override:

    [assign clear=1]

## Notes

An assignment changes only the value the corresponding tag returns; downstream
behavior such as currency formatting still applies normally.

`shipping` and `handling` overrides are rounded to the active locale's number
of fractional digits; `subtotal` and `salestax` overrides are used exactly as
given.

## See also

- [salestax](salestax.md), [shipping](shipping.md), [handling](handling.md),
  [subtotal](subtotal.md), [total-cost](total-cost.md)
- Concepts: [cart and checkout](../guides/cart-and-checkout.md),
  [taxes](../guides/taxes.md)

## Source

Defined in `code/SystemTag/assign.coretag` (inline Routine). Writes to
`$Vend::Session->{assigned}`.
