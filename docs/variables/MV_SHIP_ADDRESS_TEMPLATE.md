# MV_SHIP_ADDRESS_TEMPLATE

Overrides the template the [address](../tags/address.md) tag uses to format a
shipping address. Reach for it to change the layout of formatted addresses
across the catalog.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_SHIP_ADDRESS_TEMPLATE  template-text

The value is a template string with `{field}` placeholders for address fields.
Default: unset (the built-in address template is used).

## Description

`tag_address` builds a formatted address from a template. When
`MV_SHIP_ADDRESS_TEMPLATE` is set, its value replaces the built-in template.
The built-in template is roughly:

    {address}
    {city}, {state} {zip}
    {country} -- {phone_day}

with a leading `{company}` line when the address has a company. Placeholders are
filled from the address's fields.

## Examples

Use a one-line address format:

    Variable  MV_SHIP_ADDRESS_TEMPLATE  {address}, {city} {state} {zip} {country}

## See also

[address](../tags/address.md), the [shipping](../guides/shipping.md) and
[cart-and-checkout](../guides/cart-and-checkout.md) guides.

## Source

Consumed in `lib/Vend/Interpolate.pm` (`tag_address`) via
`$::Variable->{MV_SHIP_ADDRESS_TEMPLATE}`.
