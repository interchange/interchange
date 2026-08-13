# Shipping

Defines named shipping modes and their settings in `catalog.cfg`, as an
alternative (or complement) to the flat shipping file. Reach for it to configure
query-based carriers such as UPS or postal lookups, and to set where the
shipping rate files live.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Shipping  MODE  key value [key value ...]

Each line names a shipping mode and gives one or more `key value` attribute
pairs for it (shell-quoting applies, so values with spaces must be quoted).
Repeating the directive with the same mode name adds more attributes to that
mode. Default: empty.

## Description

`Shipping` populates a repository of shipping-mode definitions
(`Shipping_repository`), each keyed by mode name. A mode's attributes drive how
its cost is calculated -- for example `default_geo` for a query carrier's origin
postal code, or `dir` / `directory` and `config_file` to point at the rate
files a mode reads.

The special mode named `default` supplies catalog-wide settings, such as the
base directory Interchange reads shipping rate files from; if unset, that
directory defaults to [ProductDir](ProductDir.md). When any `Shipping` modes are
defined, Interchange gathers each mode's `config_file` (plus the conventional
`shipping.asc`) when reading shipping data.

This is the modern, mode-oriented way to configure shipping. It works alongside
the flat shipping table and [CustomShipping](CustomShipping.md) (an SQL query
source); [DefaultShipping](DefaultShipping.md) picks which mode applies when the
cart specifies none.

## Examples

Set up postal and UPS query modes with an origin ZIP, and point the `default`
mode at the rate-file directory. From the strap demo `catalog.cfg`:

```
Shipping   Postal     default_geo   45056
Shipping   QueryUPS   default_geo   45056
Shipping   default    dir           products/ship
```

## See also

[DefaultShipping](DefaultShipping.md), [CustomShipping](CustomShipping.md),
[TaxShipping](TaxShipping.md), [ProductDir](ProductDir.md),
[Database](Database.md), the [shipping](../guides/shipping.md) guide.

## Source

Parsed by `parse_locale` in `lib/Vend/Config.pm` (into `Shipping_repository`).
Consumed in `lib/Vend/Ship.pm` (`read_shipping`, `resolve_shipmode`).
