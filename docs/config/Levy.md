# Levy

Defines a named **levy** -- a charge added to an order, such as sales tax,
shipping, handling, or a custom fee -- as a set of keyed settings. Reach for
it to describe each order-level charge you want the levy engine to compute,
then activate them with [Levies](Levies.md).

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Levy  NAME  KEY  VALUE

Parsed like [Locale](Locale.md): the first token is the levy `NAME`,
followed by a `KEY VALUE` pair (or a `{ ... }` Perl hash). Repeat the
directive with the same `NAME` to add more keys to that levy. Each named
levy is stored in the catalog's levy repository. Default: empty.

## Description

A levy is one line of order-level cost. Defining a `Levy` only registers
it; it is computed and shown only when its name is listed in
[Levies](Levies.md). When the cart total is figured, the levy engine walks
the active levies, evaluates each one's conditions, computes its cost
according to its `type`, and appends a levy line to the order.

Recognized keys (all optional except that most levies need a `type`):

| Key | Effect |
|-----|--------|
| `type` | `salestax`, `shipping`, `handling`, or `custom`. Defaults to `salestax` when the name is `salestax`, else `shipping`. |
| `mode` | Charge mode passed to the shipping/custom routine (default: the levy name). |
| `mode_from_values` | Take `mode` from this values-space field instead. |
| `mode_from_scratch` | Take `mode` from this scratch variable instead. |
| `include_if` | Apply the levy only if this condition (a values field name, ITL, or calc) is true. |
| `exclude_if` | Skip the levy if this condition is true. |
| `sort` | Sort key for ordering levy lines (defaults: salestax `010`, handling `100`, shipping `500`). |
| `group` | Grouping label (default: the `type`). |
| `description` | Description text; combined with `label_value` via `errmsg`. |
| `multi_description` | Description to use when several shipping modes apply. |
| `label` | Display label (default: the computed description). |
| `label_value` | A values field interpolated into the description. |
| `part_number` | Part number recorded on the levy line. |
| `keep_if_zero` | Keep the levy line even when its cost is zero (marks it free). |
| `free_message` | Message shown when a kept levy costs zero. |
| `inclusive` | Mark the levy inclusive -- excluded from the added total (e.g. tax already in prices). |
| `add_to` | Fold this levy's cost into another named levy line instead of adding its own. |
| `tax_fields` | For `salestax`, override the [SalesTax](SalesTax.md) fields used. |
| `tax_type` | For `salestax`, the tax type passed to the sales-tax routine. |
| `multi` | For `salestax`, use the `multi` sales-tax mode. |
| `check_status` | Values fields whose contents feed the levy-cache key (recompute trigger). |

For `type custom`, `mode` names a [Sub](Sub.md)/`GlobalSub`/UserTag that is
called with the levy definition and returns `($cost, $description, $sort)`.

## Examples

Define a sales-tax levy and a shipping levy, then activate both:

```
Levy    salestax    description    "Sales Tax (%s)"
Levy    salestax    keep_if_zero   1
Levy    salestax    type           salestax
Levy    salestax    sort           002

Levy    shipping    keep_if_zero   0
Levy    shipping    type           shipping
Levy    shipping    mode_variable  mv_shipmode
Levy    shipping    mode           USPS

Levies  salestax shipping
```

## Notes

Levies are the modern replacement for computing tax and shipping totals
directly; see the [taxes](../guides/taxes.md) and
[shipping](../guides/shipping.md) guides for how the computed costs feed
order totals.

## See also

[Levies](Levies.md), [SalesTax](SalesTax.md), [Shipping](Shipping.md),
[TaxInclusive](TaxInclusive.md), the [taxes](../guides/taxes.md) and
[shipping](../guides/shipping.md) guides.

## Source

Parsed by `parse_locale` in `lib/Vend/Config.pm` (stored in the catalog
`Levy_repository`); evaluated by the `levies` routine in
`lib/Vend/Interpolate.pm`.
