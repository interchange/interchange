# MV_PAYMENT_PRECISION

Sets the number of decimal places used when formatting the amount sent to the
payment gateway. Reach for it when a gateway or currency requires a precision
other than two decimals.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_PAYMENT_PRECISION  digits

`digits` is a non-negative integer. Default: `2`.

## Description

`MV_PAYMENT_PRECISION` is the variable-space source for the payment `precision`
parameter. When `charge()` formats the transaction amount, it uses
`charge_param('precision')` (route option or this variable), defaulting to `2`.
The amount is rounded and formatted to that many decimal places before being
sent to the gateway.

## Examples

Send whole-unit amounts (no decimals):

    Variable  MV_PAYMENT_PRECISION  0

## See also

[MV_PAYMENT_CURRENCY](MV_PAYMENT_CURRENCY.md),
[MV_PAYMENT_MODE](MV_PAYMENT_MODE.md), the [payments](../guides/payments.md)
guide.

## Source

Consumed in `lib/Vend/Payment.pm` (`charge`, via `charge_param('precision')`)
using `$::Variable->{MV_PAYMENT_PRECISION}`.
