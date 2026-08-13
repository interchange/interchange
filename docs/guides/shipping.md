# Shipping

Interchange computes a shipping charge for the current cart the same way it
computes a price: from your data and your directives, never from the browser.
A **shipping mode** — `upsg`, `usps`, `Postal`, whatever you name it — is a
small rule that takes an *accumulated criterion* (the cart's total weight,
quantity, or price) and turns it into a number. This chapter explains where
modes are defined, how a cost is calculated atom by atom, the flat
`shipping.asc` file that holds most modes, zone/UPS-table lookups, live carrier
queries (USPS, UPS, ShipEngine), free shipping, and handling charges. It
assumes you know the [Interchange Tag Language (ITL)](templating.md) and how a
[catalog is configured](configuration.md); shipping sits right next to
[pricing](pricing.md) and [taxes](taxes.md) in the
[order total](cart-and-checkout.md).

The shopper picks a mode; its code lives in the `mv_shipmode` form value. At
checkout, [subtotal](../tags/subtotal.md), [salestax](../tags/salestax.md), and
[total-cost](../tags/total-cost.md) call the shipping engine to price that mode
for the current cart, and the [shipping](../tags/shipping.md) tag displays the
result. Everything below is what happens between "shopper chose `upsg`" and
"shipping: $7.42."

## The two places modes are defined

A catalog defines shipping modes in one or both of these:

- **The flat shipping file, `shipping.asc`** — a text file (by convention in
  `products/ship/`) listing every mode and its cost rules. This is where the
  bulk of your modes live, and where all the calculation forms below apply. It
  is read into `$Vend::Cfg->{Shipping_line}` at catalog startup.
- **The [Shipping](../config/Shipping.md) directive in `catalog.cfg`** — a
  mode-oriented *repository* (`Shipping_repository`) that carries per-mode
  settings for query carriers and names the directory the rate files live in.
  The special mode `default` supplies catalog-wide settings.

The strap demo uses both. Its `catalog.cfg` points the engine at the rate-file
directory and configures the two query carriers:

```
Shipping   Postal     default_geo   45056
Shipping   QueryUPS   default_geo   45056
Shipping   default    dir           products/ship
```

and its `products/ship/shipping.asc` holds the actual modes (`upsg`, `ups3`,
`pm`, `air_pp`, …). If `Shipping default dir` is unset, the file directory
falls back to [ProductDir](../config/ProductDir.md).

Two more sources feed the same `Shipping_line` list:

- [CustomShipping](../config/CustomShipping.md) — when set to a value beginning
  `select `, Interchange runs it as an SQL query (interpolated as ITL first)
  and uses the returned rows as shipping lines instead of, or in addition to,
  the file. Use it when your rate rules live in a database table.
- `Variable MV_SHIPPING` — a whole `shipping.asc` inline in `catalog.cfg`,
  written out to a scratch file and read. Handy for small catalogs that want
  everything in one config file.

## How a cost is calculated

`Vend::Ship::shipping` (in `lib/Vend/Ship.pm`) prices one mode. The
[shipping](../tags/shipping.md) tag, `salestax`, and `total-cost` all reach it
through `tag_shipping`. Given a mode:

1. **Select the mode's lines.** Every `Shipping_line` whose code *begins with*
   the mode name is gathered (so a mode may span several lines — see qualifiers
   below). No lines, no cost.
2. **Compute the accumulated criterion** from the first line's `crit` field:
   the cart's total weight, quantity, price, or a number (details next). Call
   it `$total`.
3. **Walk the lines** (the `SHIPIT` loop): the first line whose `min ≤ $total ≤
   max` (and whose qualifier matches, if any) supplies the **cost**, whose
   first character selects a calculation form. The result accumulates into
   `$final`. Normally the walk stops at the first matching line; the `continue`
   option keeps it going.
4. **Post-process** `$final`: apply `PriceDivide`, `adder`, `round`, and
   `at_least`; substitute `free` text for a zero cost; run any
   `shipping_callout`.
5. **Format** through [currency](../tags/currency.md) unless the caller asked
   for a raw number.

A mode name must match `[A-Za-z0-9_]`; whitespace, commas, or nulls in
`mv_shipmode` are read as *several* modes whose costs are summed. Recursion
(one mode calling another, below) is capped at 100 levels.

### The criterion field

The first line of a mode names what to accumulate. The forms, from
`shipping()`:

| `crit` value | Accumulated criterion |
|--------------|-----------------------|
| `weight` (or any product column) | Σ (column value × quantity) over the cart |
| `quantity` | total quantity of all cart items |
| `table:column` | Σ (that table's column for the SKU × quantity) |
| a plain number | used directly as the criterion |
| text containing a space, `[`, or `__` | interpolated as ITL; first word is the criterion, the rest becomes a **qualifier** |

So `crit weight` sums the `weight` column of every line (the usual case),
`crit quantity` counts units, and `crit [subtotal noformat=1]` uses the cart's
dollar subtotal — the basis for price-banded shipping. A bare column name that
does not exist logs an error and returns 0.

Two hooks refine the weight criterion:

- Set `Variable MV_SHIP_MODIFIERS` to a list of item-modifier names, and a
  matching `crit` reads the value off the cart line (e.g. a per-line
  `shipping_weight` attribute) instead of the product table.
- A [SpecialSub](../config/SpecialSub.md) named `weight_callout` is called with
  the summed weight and may return an adjusted figure (dimensional weight,
  minimum billable weight, and so on).

### The cost field: calculation forms

The matching line's `cost` field is dispatched on its first character. These
are the ways shipping cost is produced:

| Cost field | Meaning |
|------------|---------|
| `12.50` (digits) | fixed amount, added directly |
| `x` | multiply the criterion by the `multiplier` option |
| `x 1.5` | multiply the criterion by 1.5 |
| `f FORMULA` | a Perl formula; `@@TOTAL@@` and `@@CRIT@@` become the criterion, evaluated in the [Safe compartment](perl-embedding.md) |
| `u` / `A`–`Z` | a **zone lookup** (UPS-style rate table by geography — see below) |
| `s TYPE EXTRA` | call a **custom shipping module** `Vend::Ship::TYPE::calculate` (Postal, QueryUPS, …) |
| `i CHAIN` | a [CommonAdjust](../config/CommonAdjust.md)-style chained lookup applied per cart item |
| `m CHAIN` | the same chain applied once to the whole cart |
| `>>mode` | redirect: price `mode` instead (used for tiered/free-shipping switches) |
| `e MESSAGE` | error: return 0 and append `MESSAGE` to `$Session->{ship_message}` |

A few worked lines from strap's `shipping.asc` show the common ones. Fixed and
formula bands:

```
usps: US Post
    crit    [subtotal noformat=1]
    min     0
    max     0
    cost    0
    min     0
    max     50
    cost    f 7 + (1 * @@TOTAL@@ / 10)
    min     50
    max     99999
    cost    f @@TOTAL@@ * .05
```

A subtotal from 0.01–50 costs `7 + 10% of the order`; above 50 it is a flat 5%.
The `min 0 max 0` line catches an empty cart with cost 0.

The `e` form guards the top of a mode ("nothing to ship") and the bottom ("too
heavy"):

```
upsg: UPS Ground
    crit        weight
    min 0  max 0        cost e No shipping needed!
    min 0  max 150      cost u
    min 150 max 9999999 cost e Too heavy for UPS
```

### Redirect and multi-line modes

A cost of `>>othermode` re-prices under a different mode — the mechanism behind
"free over $99." Strap's `free_or_upsg` reads the subtotal and either charges
UPS Ground or falls through to a free line:

```
free_or_upsg: UPS Ground
    crit    [subtotal noformat=1]
    min     0
    max     99.99
    cost    >>upsg
    min     99.99
    max     9999999
    cost    0.00
    free    Free!
```

Under $99.99 it redirects to `upsg`; at or above, cost is 0 and the `free`
option substitutes the word `Free!` for the empty amount (see
[Free shipping](#free-shipping)).

Note the subtlety that makes multi-line modes work: only the **first** line
that exactly matches the mode name carries the *main* criterion; later lines
sharing the name (or the name plus a qualifier word) are candidate cost bands.
When a `min` key appears, `read_shipping` starts a new band, so the indented
`min`/`max`/`cost` blocks above become separate `Shipping_line` rows for the
same mode.

## The shipping file format

`shipping.asc` supports two syntaxes, and you can mix modes of each in one
file.

**Tab-delimited** — the historic eight-column form, one band per line:
`code`, `description`, `crit`, `min`, `max`, `cost`, `query`, `options`. Fields
are separated by a single tab and none are case-sensitive:

```
upsg	UPS Ground	weight	0	150	u	 	
upsg	UPS Ground	weight	150	9999	e Too heavy	 	
```

**Colon/key-value** — the modern, readable form the strap demo uses. A line
`mode: Description` opens a mode; indented `key value` lines set its fields
until the next `mode:` or the next `min`, which begins a new band:

```
upsg: UPS Ground
    crit    weight
    adder   2
    min     0
    max     150
    cost    u
```

Field-name keys map to the eight columns (`crit`/`criteria`/`criterion` →
criterion, `price` → cost, `min`/`minimum`, `max`/`maximum`, `sql` → query,
`description`); any other key becomes a per-mode **option** (`adder`,
`aggregate`, `zone`, …) collected into the line's option hash. Continuation
uses a trailing `\`, and a here-document (`key <<EOF … EOF`) sets a multi-line
value such as a long formula.

Because the file is read at startup, changing it requires a catalog reconfig
([configuration](configuration.md#startup-reconfiguration-and-debugging)); the
[shipping](../tags/shipping.md) tag's `add=`, `file=`, and `reset_modes=`
attributes re-read definitions at request time for testing or per-request
rates.

### Per-mode options

Options are the extra `key value` lines. The ones the engine actually consumes
(from `lib/Vend/Ship.pm`):

| Option | Effect |
|--------|--------|
| `description` | the mode's label; shown by [shipping-desc](../tags/shipping-desc.md) and `%D` in menus |
| `adder` | amount added to the final cost; may be a formula with `@@TOTAL@@` (final cost) / `@@CRIT@@` (criterion), evaluated in Safe |
| `at_least` | floor: raise the cost to this if it is lower |
| `round` | round the cost *up* to the next whole unit (`POSIX::ceil`) |
| `multiplier` | the factor for a bare `x` cost |
| `continue` | keep walking cost bands after a match instead of stopping |
| `free` | text to show when the cost is 0 (see below) |
| `next` | if the final cost is 0, price this other mode instead |
| `additional` | space-separated modes whose costs are added to this one |
| `PriceDivide` | divide the cost by [PriceDivide](../config/PriceDivide.md) (currency scaling) |
| `limit` / `filter` | restrict which cart lines count, by a line field matching `filter` |
| `perl` / `mml` | evaluate the `crit` field (and `qual`) as Perl/MML rather than a column name |

Zone and query modes read a further set (`zone`, `table`, `geo`,
`default_geo`, `aggregate`, `packaging_weight`, `source_grams`/`source_kg`/
`source_oz`, `oz`, `surcharge_table`, `residential`, `country_prefix`, …),
covered under the lookups below.

A global-options line whose cost begins `o ` sets defaults for every following
mode in the file — `cost o PriceDivide=0`, for instance, turns off currency
division catalog-wide. (Older manuals show a `g` prefix for this; the current
engine uses `o`.)

> **Not consumed by the engine.** Strap's modes carry `ups 1` and
> `ui_ship_type UPSI` keys. These are markers for the [admin UI](admin-ui.md)'s
> shipping editor, not inputs to the cost calculation — `lib/Vend/Ship.pm`
> never reads them. Do not assume every key in a shipped mode affects the
> price.

## Zone and UPS-table lookups

A cost of `u` (or a single capital `A`–`Z`) does a **zone lookup**: translate
the destination postal code to a *zone* via a zone chart, then read the rate
for that zone and weight from a rate table. This is how the bundled UPS rate
CSVs work without any live API.

Three pieces cooperate:

- **The rate table** — a [Database](../config/Database.md) whose rows are zones
  and columns are weights (strap ships `Ground.csv`, `2ndDayAir.csv`, etc.).
  Named by the mode's `table` option.
- **The zone chart** — maps the first three characters of the postal code to a
  zone column in the rate table. Named by the mode's `zone` option (strap's
  `Zone.csv`, keyed `450`), or globally by
  [UpsZoneFile](../config/UpsZoneFile.md). The engine normalizes both the UPS
  `.csv` format and a plain tab chart.
- **The destination** — the postal code from the value field named by `geo`
  (default `zip`), falling back to `default_geo`.

Strap's UPS Ground mode:

```
upsg: UPS Ground
    crit            weight
    zone            450
    table           Ground
    default_geo     45056
    aggregate       1
    surcharge_table Xarea
    residential     1
    adder           @@TOTAL@@ * ($Variable->{UPS_ADDER_PCT} || .20)
    min 0 max 0     cost e No shipping needed!
    min 0 max 1000  cost u
    min 150 max 9999999 cost e Too heavy for UPS
```

`tag_ups` (also in `lib/Vend/Ship.pm`) rounds weight up, applies these options,
and looks up the cost. Options specific to zone lookups:

- `aggregate N` — for weights over `N`, split into multiple `N`-unit packages
  and sum their costs (UPS caps single packages; strap uses this with the
  Xarea surcharge).
- `surcharge_table` / `surcharge_field` — add a per-ZIP surcharge (extended
  area, residential-area fees) from another table.
- `residential` / `residential_field` — add a residential surcharge when the
  shopper's `mv_ship_residential` value is set.
- `packaging_weight` — grams/pounds added before lookup.
- `source_grams` / `source_kg` / `source_oz`, `oz` — convert the criterion's
  weight unit into what the tables expect.
- `country_prefix` — key the zone by `COUNTRY:zip` for international charts.

The single-capital-letter form (`cost C …`, `cost R …`) selects one of 26
secondary named zones; it is superseded by naming zones directly with the
`zone` option and kept for backward compatibility.

## Live carrier queries

For real-time rates, a mode's cost calls out to a carrier's web API instead of
a local table. Two integration styles exist.

### `s` custom-shipping modules

`cost s TYPE` invokes `Vend::Ship::TYPE::calculate` with the mode, criterion,
line, and options. The mode is registered in the
[Shipping](../config/Shipping.md) repository so its settings (origin ZIP, table
names) are available. Two ship with Interchange:

- **`Postal`** (`lib/Vend/Ship/Postal.pm`) — US Postal Service international
  rates. It looks up a country's service *zone* in a `usps` table, then reads
  the rate for that zone and weight from a per-service table (`air_pp`,
  `surf_pp`, `ems`). Strap's `air_pp` mode uses `cost s Postal`. Configure the
  origin with `Shipping Postal default_geo 45056`.
- **`QueryUPS`** (`lib/Vend/Ship/QueryUPS.pm`) — the legacy UPS online rate
  lookup via the CPAN `Business::UPS` module (`cost s QueryUPS`). It requires
  `Business::UPS` installed and reads `Variable UPS_ORIGIN`,
  `UPS_COUNTRY_FIELD`, `UPS_POSTCODE_FIELD`. Strap ships commented-out `1DA`
  and `2DA` modes as examples.

Both share options with the zone lookups (`aggregate`, `packaging_weight`,
weight-unit conversions), so a `Postal` mode can aggregate 70-lb parcels the
same way a `u` mode does.

### Query tags used inside a formula

The newer carrier integrations are ITL tags you call from an `f` (formula) cost
or a page, returning a bare number:

- [shipengine](../tags/shipengine.md) — the ShipEngine REST API, a multi-carrier
  aggregator. Delegates to `lib/Vend/Ship/ShipEngine.pm`, caches responses per
  session, and is configured entirely through `SHIPENGINE_*`
  [Variable](../config/Variable.md)s. Discover your service codes with
  `[shipengine carrier_summary=1]`.
- [ups_rest_api](../tags/ups_rest_api.md) — UPS's current OAuth/REST rating API
  (`lib/Vend/Ship/UPS/REST.pm`), the modern replacement for the
  `Business::UPS`-based `QueryUPS`.
- [ups-query](../tags/ups-query.md) and [usps-query](../tags/usps-query.md) —
  older screen/API scrapers kept for compatibility.

A typical live-rate band passes the accumulated weight through the criterion
placeholder:

```
upsg_live: UPS Ground (live)
    crit    weight
    min     0
    max     150
    cost    f [ups_rest_api mode=ground weight="@@TOTAL@@"]
```

Because the tag returns a number, wrapping it in an `f` band lets you still add
handling, round, or floor with the usual options.

## Free shipping

There is no "free shipping" switch — you express it with the forms already
described, three common ways:

- **Redirect over a threshold.** The `free_or_upsg` mode above charges UPS
  under $99.99 and 0 above it. The `free` option supplies display text so the
  shopper sees `Free!` rather than an empty column.
- **A zero-cost mode.** A mode whose cost is `0` with `free Free shipping`
  always ships free. Without a `free` value, a zero cost renders as an *empty
  string*, so set `free` whenever a mode can legitimately cost nothing.
- **A discount, not a mode.** Assign the shipping charge to 0 for qualifying
  carts with [assign](../tags/assign.md) (below), leaving the mode list intact.

The `free` text is itself interpolated, so `free [L]Free over $99[/L]` localizes
cleanly.

## Handling charges

**Handling** is a second, parallel charge with its own mode, kept in the
`mv_handling` value and priced by the [handling](../tags/handling.md) tag
(`Vend::Interpolate::tag_handling`). It runs through the exact same engine as
shipping — you define handling modes in `shipping.asc` just like shipping modes
— but is totaled separately, so you can, for example, add a flat order-handling
fee on top of carrier shipping:

```
handling: Order handling
    crit    quantity
    min     0
    max     9999
    cost    2.50
```

```
Handling: [handling]      →   $2.50
```

Set `mv_handling` on a form or with [DefaultShipping](../config/DefaultShipping.md)'s
sibling `ValuesDefault mv_handling`. In the order total, handling is added
whenever `mv_handling` is set, independently of shipping.

## Displaying and choosing modes

The [shipping](../tags/shipping.md) tag is the display face of the engine.

Show the current cart's cost under the selected mode:

```
Shipping: [shipping]
```

Get a raw number for a calculation:

```
[tmp raw][shipping mode=upsg noformat=1][/tmp]
```

Build a shipping-method menu. `[shipping possible=1]` returns the modes valid
for the current destination (resolved from the `state`/`country` value fields
against the `state` and `country` tables), and [shipping-desc](../tags/shipping-desc.md)
labels each:

```
<select name="mv_shipmode">
[loop list="[shipping possible=1]"]
  <option value="[loop-code]">
    [shipping-desc mode="[loop-code]"] — [shipping mode="[loop-code]"]
  </option>
[/loop]
</select>
```

or let the tag render the whole widget:

```
[shipping label=1 widget=select]
```

`[shipping check_validity=1]` and `[shipping resolve=1]` keep `mv_shipmode`
consistent as the destination changes — resolve swaps in a valid mode when the
current one becomes unavailable. [shipping-desc](../tags/shipping-desc.md)
returns any field of a mode's definition (`[shipping-desc mode=upsg key=s_time]`
for a transit-time key you added), localized through `errmsg`. The strap
checkout page `pages/ord/shipmode.html` is a complete worked example, including
validating the chosen mode against the country's allowed `shipmodes`.

## Where shipping enters the order total

At checkout the total-building tags call the engine for you:

- [subtotal](../tags/subtotal.md) is goods only.
- [shipping](../tags/shipping.md) and [handling](../tags/handling.md) add the
  two delivery charges for the selected modes.
- [salestax](../tags/salestax.md) taxes goods, and — if the current mode is
  listed in [TaxShipping](../config/TaxShipping.md) — the shipping charge too
  (whole-word, case-insensitive match); whether tax is added or treated as
  included depends on [TaxInclusive](../config/TaxInclusive.md). See
  [Taxes](taxes.md).
- [total-cost](../tags/total-cost.md) sums subtotal + shipping + handling +
  tax.

To **override** any computed charge for the session — a customer-service price,
a negotiated rate, a coupon that zeroes shipping — use
[assign](../tags/assign.md). An assigned value wins over recalculation:

```
[assign shipping=0]                  free shipping this session
[assign handling=5.00 shipping=12]   fixed charges
[assign clear=1]                     back to calculated rates
```

`assign` accepts only numbers for `shipping`, `handling`, `salestax`,
`subtotal`, and `credit`; a non-numeric value is logged and dropped.

## Notes and edge cases

- **A zero cost with no `free` renders empty.** `shipping()` returns `''` when
  `$final == 0` and no `free` option is set. Always give genuinely-free modes a
  `free` value, or the checkout shows a blank where a price belongs.
- **`ship_message` collects errors.** `e`-form costs, failed zone lookups, and
  "no match" append to `$Session->{ship_message}`, readable as
  `[data session ship_message]`. Surface it on the checkout page while
  configuring rates; the `[shipping]` tag itself returns 0 on most failures.
- **`mv_shipmode` holding several modes** (space/comma separated) sums their
  costs — usually a configuration mistake, occasionally deliberate for combined
  charges. `resolve`/`possible` operate on the list.
- **Weight is a convention, not a field name the engine requires.** `crit
  weight` sums whatever column you name; strap happens to call it `weight` and
  precomputes a `total_weight` scratch for display. The engine multiplies the
  column by quantity — make sure the product column is populated or every line
  contributes 0.
- **Formula and adder Perl runs in Safe.** `f` costs and formula `adder`s
  evaluate in the [Safe compartment](perl-embedding.md), so they have the same
  restrictions as any catalog Perl and can reach `$Variable`, `$Values`, and
  the cart. A bad formula logs an error and returns 0.
- **`shipping_callout` gets the last word.** A [SpecialSub](../config/SpecialSub.md)
  named `shipping_callout` is called with `($final, $mode, $opt, $o)` after all
  calculation; return a number to override the computed cost (fuel surcharges,
  rounding policy, audit logging).

### Honest gaps

- **`crit` returning ITL with a qualifier** (a space-separated second word) is
  matched against later lines' `crit` fields as a *qualifier* rather than a
  criterion. This qualifier path is exercised by the `i`/`m` chained forms and
  by geography-restricted UPS bands (`crit weight AK HI`); its interaction with
  `perl`/`mml` criteria is subtle and best confirmed by watching
  `$Session->{ship_message}` (left populated unless the `no_ship_message`
  [Limit](../config/Limit.md) is set). The forms in this chapter cover the
  cases the shipped catalogs use; unusual combinations should be verified
  against `lib/Vend/Ship.pm` directly.
- **Strap's `shipping.asc` defines `pm:` (Priority Mail) twice**, with
  different tables and zones. The engine takes the lines in file order for a
  mode, so the earlier definition's bands win where they overlap. This looks
  like demo-data drift rather than an intended feature; do not rely on the
  second block being reached.

## See also

- [Shipping](../config/Shipping.md), [CustomShipping](../config/CustomShipping.md),
  [DefaultShipping](../config/DefaultShipping.md),
  [UpsZoneFile](../config/UpsZoneFile.md),
  [TaxShipping](../config/TaxShipping.md) — the shipping directives
- [shipping](../tags/shipping.md), [shipping-desc](../tags/shipping-desc.md),
  [handling](../tags/handling.md), [assign](../tags/assign.md),
  [subtotal](../tags/subtotal.md), [salestax](../tags/salestax.md),
  [total-cost](../tags/total-cost.md) — the tags
- [shipengine](../tags/shipengine.md), [ups_rest_api](../tags/ups_rest_api.md),
  [ups-query](../tags/ups-query.md), [usps-query](../tags/usps-query.md) — live
  carrier tags
- [Pricing](pricing.md), [Taxes](taxes.md),
  [Cart and checkout](cart-and-checkout.md) — the rest of the order total
- [Configuration](configuration.md), [Databases](databases.md),
  [Templating](templating.md), [Embedded Perl](perl-embedding.md),
  [Internationalization](internationalization.md) — the machinery shipping
  builds on

## Source

- `lib/Vend/Ship.pm` — `read_shipping` (parse the file/repository),
  `shipping` (price one mode), `tag_shipping`/`tag_handling` (the tags),
  `tag_ups` (zone lookup), `resolve_shipmode` (valid-mode discovery),
  `tag_shipping_desc`
- `lib/Vend/Ship/Postal.pm`, `QueryUPS.pm`, `ShipEngine.pm`, `UPS/REST.pm` —
  the custom/live carrier modules
- `lib/Vend/Interpolate.pm` — `salestax` (the `CHECKSHIPPING` block) and the
  order-total assembly that call the engine
- `lib/Vend/Config.pm` — the `Shipping`, `CustomShipping`, `DefaultShipping`,
  `UpsZoneFile`, `TaxShipping` directives
- `code/SystemTag/shipping.coretag`, `shipping_desc.coretag`,
  `handling.coretag`, `assign.coretag` — the tag definitions
- `dist/strap/catalog.cfg`, `dist/strap/products/ship/shipping.asc` — the
  demo's shipping configuration and rate files
