# shipengine

Query the ShipEngine REST API for a live shipping rate. You reach for
`[shipengine]` inside a custom shipping mode (typically `shipping.asc`) to
return the cost of shipping the current cart by a given carrier service.

## Syntax

    [shipengine mode=SERVICE_CODE weight=POUNDS]

Standalone tag (no end tag). Positional order is `mode`, then `weight`.
Returns a bare number (the rate), so its output is not reparsed as Interchange
Tag Language (ITL).

## Attributes

| Attribute        | Default | Description                                        |
|------------------|---------|----------------------------------------------------|
| `mode`           |         | Carrier service code to price (e.g. `ups_ground`). |
| `weight`         | `0`     | Package weight in pounds.                           |
| `service`        |         | Alternate name for `mode`; used when `mode` empty.  |
| `carrier_summary`|         | If true, return available carriers/service codes as JSON instead of a rate. |
| `output_debug`   |         | If true, return the full rate response as JSON (debugging). |

Positional order: `mode`, `weight`. The tag also accepts arbitrary named
attributes (`addAttr`); only the keys above are consulted.

## Description

`[shipengine]` builds a ShipEngine `/v1/rates` request and returns the highest
matching rate for the requested service code, as a plain number. If no service
matches, it returns `0`.

The ship-to address is read from the user's `$Values` (form) space: `fname`,
`lname`, `company`, `phone_day`, `address1`, `address2`, `city`, `state`,
`zip`, and `country`. The ship-from address and API credentials come from
catalog `Variable` settings (see below). Weight is sent in pounds against a
custom package type.

Each result is cached in the session keyed by a serialized copy of the request;
a successful response is reused for one hour, a failed one for five seconds, so
repeated calls on a page (or across the checkout flow) do not re-hit the API.
API errors are appended to `$Session->{ship_message}` for display.

Two diagnostic modes short-circuit the rate lookup: `[shipengine
carrier_summary=1]` returns the carriers and service codes enabled for your
account (use it to discover the value for `mode`), and `[shipengine weight=3
output_debug=1]` returns the raw rate response as formatted JSON.

### Required catalog variables

Set these in `catalog.cfg`:

    Variable SHIPENGINE_API_KEY        your_api_key
    Variable SHIPENGINE_CARRIERS       se-1111111 se-2222222
    Variable SHIPENGINE_FROM_NAME              My Company
    Variable SHIPENGINE_FROM_COMPANY_NAME      My Company
    Variable SHIPENGINE_FROM_ADDRESS_LINE1     123 Main St
    Variable SHIPENGINE_FROM_CITY_LOCALITY     Anytown
    Variable SHIPENGINE_FROM_STATE_PROVINCE    NY
    Variable SHIPENGINE_FROM_POSTAL_CODE       99999
    Variable SHIPENGINE_FROM_COUNTRY_CODE      US

`SHIPENGINE_CARRIERS` is a whitespace- or comma-separated list of ShipEngine
carrier IDs. `SHIPENGINE_LOG_FILE` (default `var/log/shipengine.log`) and the
optional `SHIPENGINE_DEBUG_FILE` control logging of requests and responses.

## Examples

Discover the carriers and service codes available to your account:

    [shipengine carrier_summary=1]

Price ground service for a three-pound package:

    [shipengine mode="ups_ground" weight=3]

Use it in a custom shipping mode, passing the accumulated cart weight through
Interchange's shipping placeholder:

    [shipengine mode="ups_ground" weight="@@TOTAL@@"]

## Notes

- The tag requires the `Vend::Ship::ShipEngine` helper module and a working
  ShipEngine account; without `SHIPENGINE_API_KEY` the call cannot succeed.
- When several rates match one service code, the largest is returned.

## See also

- [ups_rest_api](ups_rest_api.md) — UPS REST rating
- [usps-query](usps-query.md) — USPS rating
- [shipping](shipping.md) — apply a configured shipping mode
- The [shipping guide](../guides/shipping.md)

## Source

Defined in `code/UserTag/shipengine.tag` as an inline `Routine`. Delegates the
API call to `Vend::Ship::ShipEngine`.
