# UpsZoneFile

Names the file of region-specific UPS zone data used to look up a shipping zone
from the customer's postal code. Reach for it when a UPS shipping method needs a
zone chart to price shipments.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    UpsZoneFile  path

A file path. The raw string is stored as-is. Default: empty (no zone file
loaded).

## Description

When `UpsZoneFile` is set, Interchange loads the named file as the zone
chart for
UPS-style shipping lookups and caches it. The file may be in the format
distributed by UPS, or a tab-delimited chart keyed by the three-character prefix
of the customer's postal code, which maps that prefix to a zone used with the
rate tables. The zone data is region-specific and must be obtained and updated
from UPS for rates to be correct.

## Examples

Point at a zone chart (in `catalog.cfg`):

```
UpsZoneFile  data/ups_zone.asc
```

## Notes

The zone lookup works together with the shipping-mode configuration
(`mv_shipmode`) and the corresponding shipping tables; a missing or mismatched
zone file causes the lookup to return zero. Zone data is specific to the origin
region, so a chart correct for one shipping origin is wrong for another.

## See also

[CustomShipping](CustomShipping.md), [DefaultShipping](DefaultShipping.md),
[Shipping](Shipping.md), the [shipping](../guides/shipping.md) guide.

## Source

Stored unparsed (no parse routine) in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Ship.pm` via `$Vend::Cfg->{UpsZoneFile}` during zone lookup.
