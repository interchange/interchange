# MV_ZIP_REQUIRED

Lists the countries for which the `multizip` order check requires a postal code.
Reach for it to enforce a postal-code field only for particular countries.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_ZIP_REQUIRED  "US CA ..."

A whitespace-separated list of country codes. Default: unset.

## Description

The `_multizip` order-check routine uses the country of the order to decide
whether a postal code is required. For a country that has a built-in
postal-code routine, that routine is applied. Otherwise, if the country appears
in the whitespace-delimited `MV_ZIP_REQUIRED` list, a postal code is required
and must be at least four characters; a shorter or empty value produces an
error.

## Examples

Require a postal code for US and UK orders:

    Variable  MV_ZIP_REQUIRED  "US UK"

Reference it from a form profile that runs the `multizip` check:

    &fatal=yes
    zip=multizip

## See also

[MV_STATE_REQUIRED](MV_STATE_REQUIRED.md),
[MV_COUNTRY_FIELD](MV_COUNTRY_FIELD.md), the
[order-checks](../order-checks/README.md) reference and the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

## Source

Consumed in `lib/Vend/Order.pm` (`_multizip`) via
`$::Variable->{MV_ZIP_REQUIRED}`.
