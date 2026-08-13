# MV_STATE_REQUIRED

Lists the countries for which the `multistate` order check requires a state
value. Reach for it to enforce a state field only for particular countries.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_STATE_REQUIRED  "US CA ..."

A whitespace-separated list of country codes. Default: unset.

## Description

The `_multistate` order-check routine uses the country of the order to decide
whether a state is required. For a country that has a built-in state template,
that template is enforced. Otherwise, if the country appears in the
whitespace-delimited `MV_STATE_REQUIRED` list, a state value is required and
must be at least two characters; a shorter or empty value produces an error.

## Examples

Require a state for US and Canadian orders:

    Variable  MV_STATE_REQUIRED  "US CA"

Reference it from a form profile that runs the `multistate` check:

    &fatal=yes
    state=multistate

## See also

[MV_ZIP_REQUIRED](MV_ZIP_REQUIRED.md),
[MV_VALID_STATE](MV_VALID_STATE.md),
[MV_COUNTRY_FIELD](MV_COUNTRY_FIELD.md), the
[order-checks](../order-checks/README.md) reference and the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

## Source

Consumed in `lib/Vend/Order.pm` (`_multistate`) via
`$::Variable->{MV_STATE_REQUIRED}`.
