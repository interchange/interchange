# Sales tax

Interchange calculates a tax figure for each order and adds it as a line on
the basket and checkout pages. This chapter shows you how to configure that
calculation — the built-in methods (a rate table keyed by the customer's
state or ZIP, simple per-region rates from Variables, VAT-style multi-rate
tables, a custom Perl function, or an inline tag) and the pluggable
third-party service framework (Avalara, TaxJar) for jurisdiction-accurate
live lookups. By the end you will know which method to reach for, what
counts as taxable, and how tax flows into the order total.

Every method funnels through one routine, `salestax()` in
`lib/Vend/Interpolate.pm`, exposed to pages as the
[salestax](../tags/salestax.md) tag. Start by understanding that funnel, then
pick a method.

## Where tax fits in an order

Tax is one of the order's **levies** — the same machinery that adds shipping
and handling. When a page asks for the order total, Interchange runs the
levy pass (`levies()`), which calls `salestax()` for the tax line, sorts the
lines, and sums them into `[total-cost]`. The tax line is labeled "Sales
Tax" by default. See [Cart and checkout](cart-and-checkout.md) for the levy
model and [total-cost](../tags/total-cost.md)/[subtotal](../tags/subtotal.md)
for the surrounding figures.

Two consequences follow. First, you rarely call the tax calculation
directly; you configure it once in `catalog.cfg` and let the basket and
checkout templates display `[salestax]`. Second, tax is computed against the
**taxable amount** — the cart subtotal after discounts, minus any exempt
items — not the raw subtotal (covered under
[What counts as taxable](#what-counts-as-taxable) below).

The strap demo ships a working tax setup out of the box; the tour below uses
its tables and Variables (`dist/strap/`).

## The calculation pipeline

When `salestax()` needs a figure it checks these sources **in order** and
stops at the first that applies:

1. **A value assigned into the session.** If code has assigned to
   `$Vend::Session->{assigned}{salestax}` (typically via the
   [assign](../tags/assign.md) tag), that exact amount is returned — no
   lookup, no rounding. This is how you override tax for a specific order.
2. **`SalesTax multi`.** Routes to the VAT / multi-rate engine
   (`tax_vat()`); see [VAT and multi-rate tax](#vat-and-multi-rate-tax).
3. **`SalesTax` contains a `[`.** The directive value is interpolated as
   Interchange Tag Language (ITL) and its result is the tax amount; see
   [An inline tag](#an-inline-tag-service-tags).
4. **[SalesTaxFunction](../config/SalesTaxFunction.md) is set.** Its Perl
   returns the rate table; see [A custom function](#a-custom-function).
5. **Otherwise**, the built-in `salestax.asc` rate table is used, keyed by
   the form fields `SalesTax` names; see
   [A rate table by state or ZIP](#a-rate-table-by-state-or-zip).

The single directive [SalesTax](../config/SalesTax.md) selects among 2, 3,
and 5 by its *form* — the literal word `multi`, a value containing `[`, or a
list of field names. Methods 1 and 4 layer on top. Everything the pipeline
produces is rounded to the locale's fractional digits (`round_to_frac_digits`)
except the assigned value in step 1.

## A rate table by state or ZIP

The default method. Set [SalesTax](../config/SalesTax.md) to a
comma/space-separated list of **form-value field names**, in priority order:

    SalesTax  state
    SalesTax  zip,state

At calculation time Interchange reads each named field from the customer's
[value space](templating.md) (`[value state]`, `[value zip]`), upper-cases
it, and uses the values as keys — in the order listed — into the rate table,
falling back to a `DEFAULT` key. ZIP+4 values are trimmed to five digits
before lookup.

The rate table is **not a database table**; it is the file
`products/salestax.asc` (or a `Special salestax.asc` override), read at
startup by `read_salestax()` in `lib/Vend/Data.pm`. Each line is
`KEY<TAB>rate`, keys are upper-cased on load, and a `DEFAULT` of `0` is
supplied if the file omits one. A minimal file:

    DEFAULT	0
    CA	.0725
    NY	.08

A numeric rate is multiplied by the taxable amount. A non-numeric value is
run through `chain_cost()`, so a table cell may itself contain ITL — which is
exactly how the strap demo bridges to the next method. Strap's `salestax.asc`
is a single line:

    default	[fly-tax]

Combined with strap's `SalesTax state`, every lookup misses the specific
state key, falls through to `DEFAULT`, and evaluates `[fly-tax]` — so strap's
real rates come from Variables, described next.

## Simple per-region rates with Variables

[fly-tax](../tags/fly-tax.md) computes `taxable amount * rate` where the rate
comes from catalog Variables rather than a table file. It is the lightest
setup: no data files, just a few `Variable` lines.

    Variable  TAXRATE   CA=7.25, NY=8.0, DEFAULT=0
    SalesTax  [fly-tax]

`[fly-tax]` reads these Variables at runtime:

| Variable | Meaning |
|----------|---------|
| `TAXRATE` | Comma list of `region=rate` pairs. A rate greater than 1 is treated as a percentage (divided by 100), so `7.25` and `.0725` are equivalent. |
| `TAXCOUNTRY` | If set, tax is computed only when the customer's `country` value matches one listed; otherwise `[fly-tax]` returns `0`. |
| `TAXSHIPPING` | Regions for which the shipping cost is added to the taxable amount before the rate applies. |
| `TAXHANDLING` | Regions for which the handling cost is added. |

With no explicit `area`, `[fly-tax]` derives the region by walking the field
names in `SalesTax` and taking the first non-empty customer value (usually
`state`), matched case-insensitively against `TAXRATE`. Strap ships
`Variable TAXRATE IN=6.0` and `Variable TAXFIELD state`, with
`SalesTax __TAXFIELD__`, so an Indiana address is taxed at 6% and everywhere
else at zero.

`[fly-tax]` returns a bare number; wiring it through `SalesTax` lets
`[salestax]` handle currency formatting and rounding for you. See the
[fly-tax reference](../tags/fly-tax.md) for the full attribute set.

## A custom function

When rates depend on logic a static table cannot express — a vendor, a
computed schedule, an external source — set
[SalesTaxFunction](../config/SalesTaxFunction.md) to a block of Perl (or the
name of a [Sub](../config/Sub.md)/[GlobalSub](../config/GlobalSub.md)). It is
evaluated with `tag_calc`, so the embedded-Perl objects (`$Session`,
`$Values`, `$Scratch`) are available — see [Embedded Perl](perl-embedding.md).

The function must return a hash reference keyed by the same upper-cased codes
the table lookup would use, **including a `DEFAULT` key**. Omitting `DEFAULT`
makes the tax silently come out zero.

    SalesTaxFunction  <<EOR
    return {
        DEFAULT => 0.0,
        IL      => 0.075,
        OH      => 0.065,
    };
    EOR

`SalesTaxFunction` supplies only the *table*; the keying still comes from the
`SalesTax` field list, and it applies only when `SalesTax` is neither `multi`
nor an ITL expression. Because the code runs under the Safe compartment, an
operation Safe forbids needs [SafeUntrap](../config/SafeUntrap.md). See the
[SalesTaxFunction reference](../config/SalesTaxFunction.md) for more examples.

## An inline tag (service tags)

If [SalesTax](../config/SalesTax.md) contains a `[`, its value is
interpolated as ITL for each calculation and the result is the tax amount.
This is the hook for delegating the whole computation to a tag — most often a
[third-party service](#third-party-tax-services):

    SalesTax  [tax-lookup service=taxjar]

Any tag that returns a number works here, so this is also the general escape
hatch for tax logic you express as a custom [UserTag](../config/UserTag.md).

## What counts as taxable

Before any rate is applied, `salestax()` computes the **taxable amount** with
`taxable_amount()`. Starting from the discounted cart subtotal, it removes
items you have marked exempt:

- **[NonTaxableField](../config/NonTaxableField.md)** names a product-table
  column; a line whose value there is true (`1`, `Yes`, `on`, …) is excluded
  from the taxable amount. Strap sets `NonTaxableField nontaxable`.
- **`mv_nontaxable`** on a cart line excludes that line regardless of the
  directive — useful for a runtime exemption (strap declares
  `AutoModifier nontaxable` so the flag rides along with each item).
- **Discounts** are already applied: `taxable_amount()` uses the discounted
  line subtotals and honors an `ENTIRE_ORDER` discount formula, so tax is
  charged on what the customer actually pays. See
  [Pricing](pricing.md) for the discount model.

Two directives adjust the base further:

- **[TaxShipping](../config/TaxShipping.md)** lists shipping-mode codes whose
  shipping charge is itself taxable. When the current mode matches (whole
  word, case-insensitive), the shipping cost is added to the taxable amount
  before the rate applies.
- **[TaxInclusive](../config/TaxInclusive.md)** treats displayed prices as
  already containing tax (common for European VAT). Interchange then backs
  the tax out with `rate / (1 + rate)` instead of adding it on top, and the
  levy pass does **not** add the tax line to the order total — the tax is
  reported for display but is already inside the prices.

## VAT and multi-rate tax

Set `SalesTax multi` to use `tax_vat()`, a richer engine for
value-added-tax and layered country/state taxes. Instead of one rate keyed by
one field, it resolves a tax *type* per country and can stack multiple
component taxes.

The engine reads a country table and (optionally) a state table, whose names
and fields default to catalog Variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `MV_COUNTRY_TABLE` | `country` | Table holding per-country tax info |
| `MV_COUNTRY_TAX_FIELD` | `tax` | Column giving the country's tax type |
| `MV_COUNTRY_TAX_VAR` | `country` | Form field naming the customer's country |
| `MV_STATE_TABLE` | `state` | Table holding per-state tax |
| `MV_STATE_TAX_FIELD` | `tax` | Column giving the state's tax |
| `MV_TAX_CATEGORY_FIELD` | `tax_category` | Product column selecting a per-category rate |

The `tax` column value drives the behavior:

- A bare word names another form field (usually `state`), sending the lookup
  to the state table.
- A percentage such as `20%` taxes the whole taxable amount at that rate
  (respecting `TaxInclusive`).
- A `key=rate` option string sets **per-category** rates, matched against
  each item's `tax_category` (or the table::column named in
  `MV_TAX_CATEGORY_FIELD`), with a `default`. Reserved keys
  `mv_shipping`, `mv_shipping_when_taxable`, and `mv_handling` add tax on
  shipping and handling.
- `simple:FIELD` delegates to [fly-tax](../tags/fly-tax.md); `handling:MODES`
  taxes named handling modes.

This is the method to reach for when different product categories carry
different VAT rates, or when both a country-level and a state-level tax must
be summed. The implementation is `tax_vat()` in `lib/Vend/Interpolate.pm`.

## Third-party tax services

For jurisdiction-accurate, always-current rates — the thousands of US
sales-tax jurisdictions, or live VAT — Interchange ships a pluggable service
framework, `Vend::Tax`, patterned after the payment framework
([Payments](payments.md)). Two services are included: **Avalara**
(`Vend::Tax::Avalara`) and **TaxJar** (`Vend::Tax::TaxJar`). The base module
defines the interface through three [UserTags](../config/UserTag.md); each
service subclass implements the actual API calls.

| Tag | Role |
|-----|------|
| [tax-lookup](../tags/tax-lookup.md) | Return the tax amount for the current cart (live or estimated) |
| [load-tax-averages](../tags/load-tax-averages.md) | Populate a local averages table for offline estimates |
| [send-tax-transaction](../tags/send-tax-transaction.md) | Report a completed order back to the provider for filing |

### Enabling a service

A service module must be loaded at the **global** level — it runs full Perl,
outside the Safe compartment. Add to `interchange.cfg` (or a file it
includes):

    Require module Vend::Tax::TaxJar

Then wire the lookup into the catalog's tax field. Strap has the line ready
to uncomment in `catalog.cfg`:

    Variable  TAXFIELD  [tax-lookup service=__TAXSERVICE__]
    SalesTax  __TAXFIELD__

With `Variable TAXSERVICE TaxJar` and the provider credentials set (TaxJar
uses `Variable TAXTOKEN`; Avalara uses `AVALARA_USER` / `AVALARA_PASSWORD`),
`[salestax]` now returns provider-calculated tax. Because `TAXFIELD` contains
a `[`, the pipeline takes the ITL branch above and interpolates the tag.

### Live lookups and caching

`[tax-lookup]` builds a `Vend::Tax::<service>` object from its attributes,
sends the cart and address to the provider, and returns the amount. Address
data defaults out of the customer's [value space](templating.md): the
shipping fields (`fname`, `address1`, `city`, `state`, `zip`, `country`, …),
or the billing `b_*` counterparts when `use_billing` is true (which it is by
default whenever `zip` is empty). `country` falls back to `US`.

Live API calls cost money and latency, so each result is **cached in the
session** for `cache_timeout` minutes (default 120), keyed by an MD5 hash of
the address, cart composition, shipping, and handling. Changing any of those
invalidates the cache and triggers a fresh call; repeated page views of an
unchanged cart do not. Setting `cache_timeout=0` disables caching — strongly
discouraged outside troubleshooting.

The full attribute set (address components, order fields, `table`,
`nontaxable_field`, `development` sandbox toggle, `verbose` debug logging) is
documented on the [tax-lookup reference](../tags/tax-lookup.md) and in the
`Vend::Tax` POD; per-service specifics (`token`, `product_tax_code_field`,
nexus address Variables) are in each service module's POD.

### Estimate mode and the averages table

Live lookups on every basket view are expensive. **Estimate mode** trades
some accuracy for speed by computing tax from a local table of average rates
instead of calling the provider. It is on when the `estimate` attribute is
true — by default `$Scratch->{tag_tax_lookup_estimate_mode}`, which strap
seeds with `ScratchDefault tag_tax_lookup_estimate_mode 1`. A common pattern
is to estimate while shopping and do one authoritative live lookup at
checkout.

Estimate mode reads the **tax-averages table** (default name from Variable
`TAXAVERAGES_TABLE`, strap's `tax_averages`). The framework requires certain
columns regardless of provider:

| Column | Meaning |
|--------|---------|
| lookup field (`average_lookup_field`, default `state`) | Canonical jurisdiction key |
| `country` | Country the row applies to |
| `has_nexus` | Whether the merchant has tax liability there |
| `rate_percent` | Average rate, as a percent |
| `rate_adjust_percent` | Manual fine-tuning, ± percent applied to `rate_percent` |
| `tax_shipping` | Whether shipping is taxable in that jurisdiction |

The estimate is `taxable_amount * (rate_percent/100)`, optionally adjusted by
`rate_adjust_percent` and plus shipping when `tax_shipping` is set — and it
returns **zero when no row with `has_nexus` matches**, so you are not charging
tax where you have no liability. `rate_adjust_percent` lets a merchant nudge
an average that experience shows runs low or high (e.g. `+3` turns 8.5% into
8.755%). Strap ships the table definition and a seed `tax_averages.txt`.

### The tax jobs

Two pieces of the framework are meant to run from scheduled
[Jobs](jobs.md), not customer pages, because they reach external services and
write the database. Strap ships both under `etc/jobs/`:

- **`load_tax_averages`** refreshes the averages table. Its `execute` page is
  essentially `[load-tax-averages service=__TAXSERVICE__]`. Schedule it (say,
  nightly) so estimate mode uses current rates and current nexus.
  `[load-tax-averages]` pulls summary rates and nexus jurisdictions from the
  provider and writes them into the averages table.
- **`send_tax_transactions`** reports finished orders to the provider for tax
  filing. It queries `transactions` for rows where `tax_sent = 0` and calls
  [send-tax-transaction](../tags/send-tax-transaction.md) for each, passing
  the order number, date, totals, and address. The `tax_sent` column tracks
  state: `0`/empty means unreported, `1` reported successfully, `-1` an error
  needing manual attention.

Run a job group directly with `bin/interchange --runjobs=strap=daily`, or let
housekeeping fire it on schedule (see [Jobs](jobs.md)).

### Writing your own service

A new provider is a subclass of `Vend::Tax` that defines the `SERVICE`
constant and overrides `tax()` (and, where supported, `load_tax_averages()`
and `send_tax_transaction()`). The base class provides the constructor, the
attribute accessors, the session cache, the taxable-amount and exemption
logic, and the MD5 cache key; you supply the HTTP calls and response parsing.
`Vend::Tax::TaxJar` is the compact reference implementation. Calling a tag
with an unimplemented or absent service raises an error that is logged (not
shown to the shopper), and the tag returns nothing.

## Assigning a fixed tax

To override the calculation for one order — a negotiated amount, a manual
correction — assign directly into the session with
[assign](../tags/assign.md):

    [assign salestax=12.50]

Step 1 of the [pipeline](#the-calculation-pipeline) returns that value
verbatim, with no lookup and no rounding, until it is cleared.

## Negative tax and rounding

Discounts and credits can drive a computed tax below zero. By default the
self-computing paths already floor a negative result at zero. The
[no_negative_tax](../pragmas/no_negative_tax.md) pragma governs the two code
paths — importantly, its default behavior differs between a self-computed tax
and a pre-supplied one — so if you use a custom routine that may return a
negative cost, set the pragma explicitly rather than relying on the default.
See the [no_negative_tax reference](../pragmas/no_negative_tax.md) for the
exact semantics.

All non-assigned results are rounded to the active locale's fractional digits.

## Displaying tax on a page

Show the tax line with the [salestax](../tags/salestax.md) tag, which runs
the calculation for the current cart and formats the result as currency:

    Sales tax: [salestax]

For the raw number (for your own arithmetic), pass `noformat`:

    [salestax noformat=1]

Because the calculation reads the customer's jurisdiction from the value
fields named in `SalesTax`, those form values must be set before the figure
is correct — which is why the tax line usually appears on the checkout page,
after the address form, and updates as the customer edits their address. See
[Cart and checkout](cart-and-checkout.md) for where the line sits in the
basket and order-total templates.

## See also

- [salestax](../tags/salestax.md), [fly-tax](../tags/fly-tax.md),
  [tax-lookup](../tags/tax-lookup.md),
  [load-tax-averages](../tags/load-tax-averages.md),
  [send-tax-transaction](../tags/send-tax-transaction.md) — the tags
- [SalesTax](../config/SalesTax.md),
  [SalesTaxFunction](../config/SalesTaxFunction.md),
  [TaxShipping](../config/TaxShipping.md),
  [TaxInclusive](../config/TaxInclusive.md),
  [NonTaxableField](../config/NonTaxableField.md) — the directives
- [no_negative_tax](../pragmas/no_negative_tax.md) — the negative-tax pragma
- [Cart and checkout](cart-and-checkout.md), [Pricing](pricing.md),
  [Shipping](shipping.md) — the surrounding order figures
- [Jobs](jobs.md) — scheduling the tax-service jobs
- [Payments](payments.md) — the sibling gateway framework `Vend::Tax` mirrors
