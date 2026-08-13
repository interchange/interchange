# levies

Returns the total of the catalog's configured *levies* — the unified
tax-and-shipping charges defined by the `Levies` / `Levy` directives. Reach for
it on checkout and receipt pages in catalogs that use the levy system instead of
separate [salestax](salestax.md) and [shipping](shipping.md) calculations.

## Syntax

    [levies]
    [levies group]
    [levies recalculate=1 cart=main]

Standalone tag (no end tag).

## Attributes

| Attribute     | Default        | Description |
|---------------|----------------|-------------|
| `group`       | (none)         | Restrict the total to a named levy group. |
| `recalculate` | `0`            | Force recalculation instead of using the cached total. |
| `cart`        | current cart   | Cart whose levies are totalled. |
| `hide`        | `0`            | Calculate but return nothing. |

Positional order: `group`. The tag accepts arbitrary additional attributes
(`addAttr`).

## Description

The tag maps to an inline routine that calls `Vend::Interpolate::levies`,
passing the `recalculate`, `cart`, and full option set. If the catalog has no
`Levies` directive configured, the tag returns nothing.

A *levy* is a configured charge (a sales-tax line, a shipping line, a handling
line, and so on) declared in the `Levy` repository and listed in the `Levies`
directive. Each levy has a `type` (`salestax`, `shipping`, or `handling`), an
optional `group`, `include_if`/`exclude_if` conditions, a mode, a sort order,
and a description. The routine walks the configured levies in order, evaluates
each one's conditions, computes its cost (delegating to
[salestax](salestax.md) or [shipping](shipping.md) as appropriate), and sums
the results. The summed total is what `[levies]` returns.

For performance the total is cached per cart and reused on repeat calls in the
same request; pass `recalculate=1` to force a fresh computation (for example
after changing the cart or shipping mode). The `cart` attribute selects which
cart's levies to total; by default it uses the current cart.

## Examples

Show the total of all levies on a checkout page:

    Charges: [levies]

Force recalculation after updating the order:

    [levies recalculate=1]

Total only a specific group of levies:

    [levies shipping]

## Notes

- Levies are an alternative to computing tax and shipping separately; a catalog
  that does not define `Levies` will get an empty result. The individual levy
  lines (for display in a table) are exposed through the levy loop rather than
  this summary tag.
- The precise effect of the `group` positional in narrowing the total depends
  on how each levy's `group`/`type` is configured in the `Levy` repository;
  verify against your catalog's levy definitions.

## See also

- [salestax](salestax.md), [shipping](shipping.md) — the per-type calculators
  levies delegate to
- [total-cost](total-cost.md) — order grand total
- Guide: [Taxes](../guides/taxes.md), [Shipping](../guides/shipping.md)

## Source

Defined in `code/SystemTag/levies.coretag` (inline `Routine`). Implemented by
`Vend::Interpolate::levies` in `lib/Vend/Interpolate.pm`.
