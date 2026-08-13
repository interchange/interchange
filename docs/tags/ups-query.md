# ups-query

Calculate UPS shipping cost through the `Business::UPS` Perl module. Reach for
`[ups-query]` inside a custom shipping mode to price the current cart by a UPS
service code and weight.

> **Note:** `[ups-query]` uses the legacy UPS web interface via
> `Business::UPS`. For new work use [ups_rest_api](ups_rest_api.md), which
> speaks the current UPS REST rating API.

## Syntax

    [ups-query mode=MODE weight=POUNDS]
    [ups-query mode=MODE origin=ZIP zip=DEST country=US weight=POUNDS]

Standalone tag (no end tag). Returns a bare number (the cost), so its output is
not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute     | Default                              | Description                                  |
|---------------|--------------------------------------|----------------------------------------------|
| `mode`        |                                      | A `Business::UPS` mode (e.g. `1DA`, `2DA`, `GNDCOM`). Required. |
| `weight`      |                                      | Weight in pounds. Required.                  |
| `origin`      | `$Variable->{UPS_ORIGIN}`            | Origin ZIP code.                             |
| `zip`         | `$Values->{UPS_POSTCODE_FIELD}`      | Destination ZIP code.                        |
| `country`     | `$Values->{UPS_COUNTRY_FIELD}`       | Destination country.                         |
| `aggregate`   | off                                  | Split heavy shipments into repeated calls (see below). |
| `cache_table` | `ups_cache`                          | Table used to cache rate lookups.            |

Positional order: `mode`, `origin`, `zip`, `weight`, `country`. The tag also
accepts arbitrary named attributes (`addAttr`).

## Description

`[ups-query]` calls `getUPS()` from `Business::UPS` and returns the shipping
cost as a plain number. On error it appends the message to
`$Session->{ship_message}` and returns `0`.

Destination defaults are pulled indirectly through catalog variables: `zip`
defaults to the `$Values` field named by `UPS_POSTCODE_FIELD`, and `country` to
the field named by `UPS_COUNTRY_FIELD`. Country codes are upper-cased, `UK` is
remapped to `GB`, and further remappings can be supplied in
`UPS_COUNTRY_REMAP` (as a hash string or `key=value` option list). For US
destinations a ZIP+4 value is trimmed to the five-digit base.

### Aggregate (multi-box) shipments

`aggregate` prices shipments too heavy for a single package by splitting the
weight into multiple calls and summing them. `aggregate=1` uses a per-box
weight of `$Variable->{UPS_QUERY_MODULO}` (default 150 lb). A value above 10 is
used directly as the per-box weight. For example, `[ups-query weight=400
mode=GNDCOM aggregate=1]` is equivalent to three calls at 150, 150, and 100
pounds.

### Rate caching

If a table named by `cache_table` (default `ups_cache`) exists, lookups are
cached in it and reused for up to one day. The table needs the fields `code`,
`weight`, `origin`, `zip`, `country`, `shipmode`, `cost`, and `updated`, for
example:

    Database  ups_cache  ship/ups_cache.txt  __SQLDSN__
    Database  ups_cache  AUTO_SEQUENCE  ups_cache_seq
    Database  ups_cache  INDEX  weight origin zip shipmode country

## Examples

Price ground commercial service for an 11-pound package to an explicit
destination:

    [ups-query mode=GNDCOM origin=45056 zip=99501 country=US weight=11]

Rely on the configured origin and the customer's address on file:

    [ups-query mode=1DA weight="@@TOTAL@@"]

Aggregate a heavy shipment into 100-pound boxes:

    [ups-query weight=400 mode=GNDCOM aggregate=100]

## Notes

- Requires the `Business::UPS` module, which uses a UPS web endpoint that is no
  longer current. Prefer [ups_rest_api](ups_rest_api.md) for new catalogs.

## See also

- [ups_rest_api](ups_rest_api.md) — current UPS REST rating tag
- [usps-query](usps-query.md) — USPS rating
- [shipengine](shipengine.md) — ShipEngine rating
- The [shipping guide](../guides/shipping.md)

## Source

Defined in `code/UserTag/ups_query.tag` as an inline `Routine`.
