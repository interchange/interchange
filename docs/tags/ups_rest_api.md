# ups_rest_api

Query the UPS REST rating API for a live shipping rate. Reach for
`[ups_rest_api]` inside a custom shipping mode to price the current cart by a
UPS service; it is the modern replacement for [ups-query](ups-query.md), which
uses the retired UPS XML/`Business::UPS` interface.

## Syntax

    [ups_rest_api mode=SERVICE_CODE weight=POUNDS]

Standalone tag (no end tag). Positional order is `mode`, then `weight`.
Returns a bare number (the rate), so its output is not reparsed as Interchange
Tag Language (ITL).

## Attributes

| Attribute      | Default | Description                                             |
|----------------|---------|---------------------------------------------------------|
| `mode`         |         | UPS service code (or legacy alias, e.g. `upsg`) to price. |
| `weight`       |         | Package weight in pounds.                                |
| `show_modes`   |         | If true, return the known service codes/aliases as JSON. |
| `output_debug` |         | If true, return the collected rates as JSON (debugging). |

Positional order: `mode`, `weight`. The tag also accepts arbitrary named
attributes (`addAttr`); only the keys above are consulted.

## Description

`[ups_rest_api]` builds a UPS `RateRequest` against the `Shop` endpoint and
returns the rate for the requested service code as a plain number. Where a
legacy alias such as `upsg` is given, it is matched against the known service
aliases. If negotiated rates are available they are returned in preference to
the published rate; if nothing matches, the tag returns `0`.

The ship-to address is read from the user's `$Values` (form) space (`fname`,
`lname`, `company`, `address1`, `address2`, `city`, `state`, `zip`,
`country`). The ship-from address, credentials, and endpoint come from catalog
`Variable` settings. Each result is cached in the session keyed by a serialized
copy of the request: a successful response for one hour, a failed one for five
seconds. API errors are appended to `$Session->{ship_message}`.

`[ups_rest_api show_modes=1]` returns the service codes, names, and accepted
aliases as JSON; `[ups_rest_api weight=3 output_debug=1]` returns the collected
rates as JSON.

### Required catalog variables

If the mandatory settings are missing the tag logs the error and returns
without a rate. Set these in `catalog.cfg`:

    Variable UPS_REST_API_CLIENT_ID      XXXXXX
    Variable UPS_REST_API_CLIENT_SECRET  XXXXXX
    # sandbox endpoint; production is https://onlinetools.ups.com
    Variable UPS_REST_API_ENDPOINT       https://wwwcie.ups.com
    Variable UPS_REST_API_NEGOTIATED_RATES 1
    Variable UPS_REST_API_FROM_NAME           My Company
    Variable UPS_REST_API_FROM_SHIPPER_NUMBER XXXXXX
    Variable UPS_REST_API_FROM_ADDRESS1       123 Main St
    Variable UPS_REST_API_FROM_CITY           Anytown
    Variable UPS_REST_API_FROM_STATE          NY
    Variable UPS_REST_API_FROM_ZIP            99999
    Variable UPS_REST_API_FROM_COUNTRY        US

Obtain `CLIENT_ID`/`CLIENT_SECRET` by creating an app subscribed to the Rating
API at the UPS developer portal; the shipper number is the UPS "Billing Account
Number". `UPS_REST_API_LOG_FILE` (default `var/log/ups_rest_api.log`),
`UPS_REST_API_DEBUG_FILE`, and `UPS_REST_API_CACHE_DIR` (default
`var/ups_rest_api`) control logging and the token cache.

## Examples

List the service codes and aliases the tag understands:

    [ups_rest_api show_modes=1]

Price ground service for a three-pound package:

    [ups_rest_api mode="upsg" weight=3]

Use it in a custom shipping mode with the accumulated cart weight:

    [ups_rest_api mode="upsg" weight="@@TOTAL@@"]

## Notes

- The tag is registered as `ups_rest_api` (underscores) — that is how you
  invoke it — even though its bundled documentation and log messages call it
  `ups-rest-api`.
- Set `UPS_REST_API_NEGOTIATED_RATES` to a true value only if your account has
  negotiated rates; the negotiated charge is then preferred over the published
  one.
- The tag requires the `Vend::Ship::UPS::REST` helper module.

## See also

- [ups-query](ups-query.md) — the older UPS XML rating tag it replaces
- [shipengine](shipengine.md) — ShipEngine rating
- [usps-query](usps-query.md) — USPS rating
- The [shipping guide](../guides/shipping.md)

## Source

Defined in `code/UserTag/ups_rest_api.tag` as an inline `Routine`. Delegates the
API call to `Vend::Ship::UPS::REST`.
