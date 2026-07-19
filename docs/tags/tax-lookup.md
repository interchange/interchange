# tax-lookup

Return a sales-tax amount calculated by a third-party tax service (for example
TaxJar). Reach for `[tax-lookup]` when your `SalesTaxFunction` or a tax field
should defer to an external provider rather than Interchange's built-in rate
tables.

## Syntax

    [tax-lookup service=SERVICE]

Standalone tag (no end tag). Returns a bare number (the tax amount), so its
output is not reparsed as Interchange Tag Language (ITL).

## Attributes

The tag takes only named attributes (`addAttr`); it has no positional
parameters. Every attribute is passed straight through to the `Vend::Tax`
object, so the full list is the object's attributes. The common ones:

| Attribute      | Default                                   | Description                                              |
|----------------|-------------------------------------------|---------------------------------------------------------|
| `service`      |                                           | Tax gateway subclass to use (e.g. `TaxJar`); required for a live lookup. |
| `estimate`     | `$Scratch->{tag_tax_lookup_estimate_mode}` | If true, use the local averages table instead of a live call. |
| `table`        | `$Variable->{TAXAVERAGES_TABLE}`          | Table holding tax averages (for estimate mode).         |
| `average_lookup_field` | `state`                           | Field in `table` used to select the estimated rate.     |
| `use_billing`  | `!$Values->{zip}`                         | Use the billing (`b_*`) address components instead of shipping. |
| `cache_timeout`| `120` (minutes)                           | Session cache lifetime for live lookups; `0` disables.  |

Address components (`fname`, `lname`, `company`, `address1`, `address2`,
`city`, `state`, `zip`, `country`) and order fields (`order_number`,
`order_date`, `total_cost`, `salestax`, `subtotal`, `handling`) can also be
overridden as attributes; each otherwise defaults from `$Values` or the current
order. See `Vend::Tax` for the complete attribute list and defaults.

## Description

`[tax-lookup]` instantiates a `Vend::Tax` subclass named by the `service`
attribute (for example `Vend::Tax::TaxJar` for `service=TaxJar`), passing all
of the tag's attributes as constructor arguments. It then returns the object's
estimated tax when `estimate` is true, or the provider's live `tax()` result
otherwise. If the call dies, the error is written to the catalog error log and
the tag returns `undef`.

Without a supported, configured `service`, the underlying object cannot compute
tax and produces an error. The base module ships two companion tags,
[load-tax-averages](load-tax-averages.md) (populate the averages table used by
estimate mode) and [send-tax-transaction](send-tax-transaction.md) (report a
completed order back to the provider).

Live lookups are cached per session, keyed by an MD5 hash of the address, cart
composition, and shipping cost, for `cache_timeout` minutes to avoid repeated
billable API calls.

## Examples

Wire the provider into the catalog's tax field, as the strap demo shows
(`catalog.cfg`):

    Variable  TAXFIELD  [tax-lookup service=__TAXSERVICE__]

Force an estimated (offline) lookup from the averages table:

    [tax-lookup service=TaxJar estimate=1]

## Notes

- The provider subclass must exist and be enabled; `[tax-lookup]` alone only
  defines the interface. Estimate mode additionally needs a properly populated
  averages table (the strap demo defines `tax_averages`).
- The tag is invoked as `[tax-lookup]` (hyphen), while its implementing sub is
  `Vend::Tax::tag_tax_lookup`.

## See also

- [load-tax-averages](load-tax-averages.md) — populate the averages table
- [send-tax-transaction](send-tax-transaction.md) — report an order to the provider
- [salestax](salestax.md) — Interchange's built-in tax calculation
- The [taxes guide](../guides/taxes.md)

## Source

Defined in `code/UserTag/tax_lookup.tag`, which requires `Vend::Tax` and maps to
`Vend::Tax::tag_tax_lookup` (`MapRoutine`).
