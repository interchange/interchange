# MV_PAYMENT_CURRENCY

Sets the currency code sent to the payment gateway with a charge. Reach for it
when the gateway needs an explicit currency other than the default.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_PAYMENT_CURRENCY  code

`code` is a currency code such as `usd` or `eur`. Default: the locale's
`currency_code` if set, otherwise `usd`.

## Description

`MV_PAYMENT_CURRENCY` is the variable-space source for the payment `currency`
parameter. When `charge()` builds the amount, it takes the currency from
`charge_param('currency')` (route option or this variable); if neither is set it
uses the current locale's `currency_code`, and failing that `usd`. The resolved
currency is prepended to the amount passed to the gateway.

## Examples

Charge in euros:

    Variable  MV_PAYMENT_CURRENCY  eur

## See also

[MV_PAYMENT_MODE](MV_PAYMENT_MODE.md),
[MV_PAYMENT_PRECISION](MV_PAYMENT_PRECISION.md), the
[payments](../guides/payments.md) and
[internationalization](../guides/internationalization.md) guides.

## Source

Consumed in `lib/Vend/Payment.pm` (`charge`, via `charge_param('currency')`)
using `$::Variable->{MV_PAYMENT_CURRENCY}`.
