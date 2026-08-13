# usps-query

Calculate a United States Postal Service shipping cost through the USPS Web
Tools rate API. Reach for `[usps-query]` inside a custom shipping mode to price
the current cart by a USPS service and weight, for domestic or international
mail.

## Syntax

    [usps-query service="SERVICE" weight=POUNDS]
    [usps-query service="SERVICE" weight=POUNDS country="Country"]

Standalone tag (no end tag). Returns a bare number (the postage), so its output
is not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute     | Default                                        | Description                                    |
|---------------|------------------------------------------------|------------------------------------------------|
| `service`     |                                                | USPS service name (see list below). Required.  |
| `weight`      |                                                | Total weight in pounds. Required.              |
| `userid`      | `$Variable->{USPS_ID}`                         | USPS Web Tools user ID.                        |
| `passwd`      | `$Variable->{USPS_PASSWORD}`                   | USPS Web Tools password.                       |
| `origin`      | `$Variable->{USPS_ORIGIN}` or `UPS_ORIGIN`     | Origin ZIP (domestic).                         |
| `destination` | `$Values->{zip}` or `$Variable->{SHIP_DEFAULT_ZIP}` | Destination ZIP (domestic).               |
| `url`         | `$Variable->{USPS_URL}` or the production URL  | Rate API endpoint.                             |
| `container`   | `$Variable->{USPS_CONTAINER}` or `None`        | USPS container type (domestic).                |
| `size`        | `$Variable->{USPS_SIZE}` or `REGULAR`          | `REGULAR`, `LARGE`, or `OVERSIZE` (domestic).  |
| `machinable`  | `$Variable->{USPS_MACHINABLE}` or `False`      | `True`/`False`, PARCEL service only.           |
| `mailtype`    | `$Variable->{USPS_MAILTYPE}` or `package`      | Mail type (international).                      |
| `country`     |                                                | Destination country name; presence selects the international API. |
| `modulo`      | `$Variable->{USPS_MODULO}`                     | Max weight per box for multi-box shipments.    |

Positional order: `service`, `weight`. The tag also accepts arbitrary named
attributes (`addAttr`).

## Description

`[usps-query]` posts a `RateRequest` (domestic) or `IntlRateRequest`
(international) to the USPS Web Tools endpoint and returns the postage as a
plain number. Supplying a `country` switches it to the international API. On
error the message is appended to `$Session->{ship_message}` and the tag returns
an empty/zero result.

`service` is upper-cased and validated against the supported list; an unknown
service is rejected. The supported services are:

    EXPRESS, FIRST CLASS, PRIORITY, PARCEL, BPM, LIBRARY, MEDIA,
    GLOBAL EXPRESS GUARANTEED (and its NON-DOCUMENT variants),
    USPS GXG ENVELOPES,
    EXPRESS MAIL INTERNATIONAL (EMS) (and FLAT-RATE ENVELOPE),
    PRIORITY MAIL INTERNATIONAL (and its FLAT-RATE variants),
    FIRST CLASS MAIL INTERNATIONAL LARGE ENVELOPE / PACKAGE,
    MATTER FOR THE BLIND - ECONOMY MAIL

For international shipments a built-in table maps common country names to the
spellings USPS expects (for example `United Kingdom` becomes `Great Britain`).
You must pass the country name, not the ISO code.

`modulo` provides rudimentary multi-box handling: when it is set and less than
the shipment weight, the weight is divided into boxes of at most `modulo`
pounds and the rates summed. For example, with `modulo=10` a 34.5-pound
shipment is priced as three 10-pound parcels plus one 4.5-pound parcel.

## Examples

Price domestic Priority Mail for a five-pound package:

    [usps-query service="PRIORITY" weight=5]

Price international First-Class package service to Canada:

    [usps-query service="FIRST CLASS MAIL INTERNATIONAL PACKAGE" weight=2 country="Canada"]

Use it in a custom shipping mode with the accumulated cart weight:

    [usps-query service="PRIORITY" weight="@@TOTAL@@"]

## Notes

- You must register for USPS Web Tools and have your account moved to the
  production server; the tag does not work against the USPS test server.
- The `userid`/`passwd` are best set once as `USPS_ID` and `USPS_PASSWORD`
  catalog variables rather than passed per call.
- The USPS country table does not exactly match the demo `country` table, so
  international use may require adjusting country names.

## See also

- [ups-query](ups-query.md) — UPS (legacy) rating
- [ups_rest_api](ups_rest_api.md) — UPS REST rating
- [shipengine](shipengine.md) — ShipEngine rating
- The [shipping guide](../guides/shipping.md)

## Source

Defined in `code/UserTag/usps_query.tag` as an inline `Routine`.
