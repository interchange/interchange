# send-tax-transaction

Report a completed order's tax to a third-party tax service (for example
TaxJar), creating the transaction record the provider needs for filing. Reach
for `[send-tax-transaction]` at order-completion time when you calculate tax
with [tax-lookup](tax-lookup.md) and the provider expects each finalized order
to be posted back.

## Syntax

    [send-tax-transaction service=SERVICE]

Standalone tag (no end tag). Returns `1` on success and nothing (with an error
logged) on failure.

## Attributes

The tag takes only named attributes (`addAttr`); it has no positional
parameters. Every attribute is passed straight through to the `Vend::Tax`
service object, so the full list is that object's attributes. The essential
one:

| Attribute | Default | Description |
|-----------|---------|-------------|
| `service` |         | Tax gateway subclass to use (e.g. `TaxJar`); **required** — the tag dies without it. |

As with [tax-lookup](tax-lookup.md), address components (`fname`, `lname`,
`address1`, `city`, `state`, `zip`, `country`, …) and order fields
(`order_number`, `order_date`, `total_cost`, `salestax`, `subtotal`,
`handling`) can be overridden as attributes; each otherwise defaults from
`$Values` or the current order. See `Vend::Tax` for the complete list.

## Description

`[send-tax-transaction]` instantiates the `Vend::Tax` subclass named by
`service` (for example `Vend::Tax::TaxJar` for `service=TaxJar`), passing all
of the tag's attributes as constructor arguments, then calls the object's
`send_tax_transaction` method to record the completed order with the provider.

If `service` is missing, or the provider call dies, the error is written to the
catalog error log and the tag returns nothing; on success it returns `1`. The
base `Vend::Tax::send_tax_transaction` only raises an error — a concrete
service subclass must implement the actual transmission, so this tag does
nothing useful without a supported, configured `service`.

This is one of the three tags the tax module ships:
[tax-lookup](tax-lookup.md) (calculate tax during an order),
[load-tax-averages](load-tax-averages.md) (populate the estimate table), and
`[send-tax-transaction]` (report the finished order back to the provider).

## Examples

Post the just-completed order to the provider, typically from the order-receipt
or final route:

    [send-tax-transaction service=TaxJar]

Wired through a catalog Variable, mirroring how the demo names its service:

    [send-tax-transaction service="__TAXSERVICE__"]

## Notes

- Call this only for genuinely completed orders; it records a billable/filable
  transaction with the provider.
- The tag is invoked as `[send-tax-transaction]` (hyphen), while its
  implementing sub is `Vend::Tax::tag_send_tax_transaction`.

## See also

- [tax-lookup](tax-lookup.md) — calculate tax via the provider
- [load-tax-averages](load-tax-averages.md) — populate the averages table
- [salestax](salestax.md) — Interchange's built-in tax calculation
- The [taxes guide](../guides/taxes.md)

## Source

Defined in `code/UserTag/send_tax_transaction.tag`, which requires `Vend::Tax`
and maps to `Vend::Tax::tag_send_tax_transaction` (`MapRoutine`).
