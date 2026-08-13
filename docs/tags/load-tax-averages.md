# load-tax-averages

Populate the local tax-averages table from a configured third-party tax
service so that estimated sales tax can be calculated without a live API
call per request. Reach for it from a scheduled job that periodically
refreshes average rates.

## Syntax

    [load-tax-averages service=SERVICE]

Standalone tag (no end tag). Returns `1` on success and nothing on failure
(errors are logged, not thrown to the page).

## Attributes

| Attribute | Default  | Description |
|-----------|----------|-------------|
| `service` | *(none)* | Name of the tax-service subclass to use (for example `TaxJar` or `Avalara`). Required — the tag does nothing without it. |

The tag accepts arbitrary additional named attributes (`addAttr`); they are
passed through to the service object's constructor. Recognized keys come
from `Vend::Tax` and its service subclass — commonly `table`
(the averages table, default from the `TAXAVERAGES_TABLE` variable) and
`average_lookup_field` (default from `TAXAVERAGES_LOOKUP_FIELD`, or `state`).

## Description

`[load-tax-averages]` is a thin dispatcher over the `Vend::Tax` framework.
It requires a `service`, constructs `Vend::Tax::<service>` with all supplied
attributes, and calls that object's `load_tax_averages` method, which pulls
average tax-rate data from the provider and writes it into the local
averages table.

The base `Vend::Tax::load_tax_averages` raises an error unless overridden;
the behavior comes entirely from the concrete service subclass
(`Vend::Tax::TaxJar`, `Vend::Tax::Avalara`, or a custom one). Any exception
is caught and written to the error log via `logError`; the tag then returns
undef. On success it returns `1`.

The averages table it fills is the one consulted by
[tax-lookup](tax-lookup.md) when running in estimate mode. That table must
carry the fields the framework expects, including `country`, `has_nexus`,
`rate_percent`, `rate_adjust_percent`, `tax_shipping`, and the configured
`average_lookup_field` (for example `state`).

## Examples

The strap catalog ships a `load_tax_averages` job whose `execute` page is
essentially:

    Calling load for __TAXSERVICE__: [load-tax-averages service=__TAXSERVICE__]

where `__TAXSERVICE__` is the catalog `TAXSERVICE` variable (for example
`TaxJar`). Run it directly by name:

    [load-tax-averages service=TaxJar]

## Notes

- This tag reaches an external service and updates a database table; run it
  from a [jobs](../guides/jobs.md) page on a schedule, not from a
  customer-facing page.
- The provider credentials and any per-service settings are configured
  through catalog variables and the service subclass, not through this tag.

## See also

- [tax-lookup](tax-lookup.md) — per-request tax lookup / estimate
- [send-tax-transaction](send-tax-transaction.md) — report a completed
  order's tax to the provider
- [salestax](salestax.md) — Interchange's built-in sales-tax calculation
- [../guides/taxes.md](../guides/taxes.md)

## Source

Defined in `code/UserTag/load_tax_averages.tag` (registers the tag
`load-tax-averages`). Implemented by `Vend::Tax::tag_load_tax_averages` in
`lib/Vend/Tax.pm`, which dispatches to the `load_tax_averages` method of the
selected `Vend::Tax::<service>` subclass.
