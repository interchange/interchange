# shipping-desc

Return a field from a shipping mode's definition — by default its human-readable
description. Use it alongside [shipping](shipping.md) to label modes in a
checkout menu or to show details such as expected transit time.

## Syntax

    [shipping-desc mode]
    [shipping-desc mode=UPSG key=s_time]

Standalone tag (no end tag). Returns the requested field value, passed through
Interchange's message translation (`errmsg`) so it can be localized.

## Attributes

| Attribute | Default       | Description |
|-----------|---------------|-------------|
| `mode`    | `mv_shipmode` value, or `default` | Shipping mode to look up. |
| `key`     | `description` | Which field of the mode's definition to return. |

Positional order: `mode`, `key`.

## Description

`[shipping-desc]` maps to `Vend::Ship::tag_shipping_desc`. It looks up the named
`mode` in the catalog's shipping configuration and returns the value of the
requested `key`. If no mode is given it uses the customer's selected
`mv_shipmode`, falling back to `default`.

The `key` can be any field defined for that mode in the shipping definitions —
not only `description` but custom keys such as `p_time` (processing time) or
`s_time` (shipping time). The returned value is run through the localization
layer, so a translated version is used when one exists for the active locale.

## Examples

Show the description of the current shipping mode:

    [shipping-desc]

Loop the available modes, showing each one's description, timing, and cost
together with [shipping](shipping.md):

    [loop list="[shipping possible=1]"]
    Shipping mode:   [shipping-desc mode="[loop-code]"]
    Processing time: [shipping-desc mode="[loop-code]" key=p_time]
    Shipping time:   [shipping-desc mode="[loop-code]" key=s_time]
    Cost:            [shipping mode="[loop-code]"]
    [/loop]

Given a shipping definition like:

    usps: USPS 1st class
            p_time      1-2 business days
            s_time      3-7 business days

`[shipping-desc mode=usps]` returns `USPS 1st class` and
`[shipping-desc mode=usps key=s_time]` returns `3-7 business days`.

## See also

- [shipping](shipping.md), [loop](loop.md)
- Concepts: [shipping](../guides/shipping.md)

## Source

Defined in `code/SystemTag/shipping_desc.coretag`. Implemented by
`Vend::Ship::tag_shipping_desc`. The alias `[shipping-description]` resolves to
this tag; see [shipping-description](shipping-description.md).
