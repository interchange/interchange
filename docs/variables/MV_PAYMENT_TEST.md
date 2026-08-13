# MV_PAYMENT_TEST

Puts the payment gateway into test/sandbox mode. Reach for it while developing
so charges go to the gateway's test environment instead of processing real
money.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_PAYMENT_TEST  1

A flag (any true value). Default: unset (live mode).

## Description

`MV_PAYMENT_TEST` is the variable-space source for the payment `test`
parameter. In `charge()`, Interchange sets `$pay_opt->{test} =
charge_param('test')`, so a true value here (when not overridden by a route
option) tells the gateway module to operate in test mode. How test mode is
expressed depends on the specific gateway module.

## Examples

Enable test mode while developing:

    Variable  MV_PAYMENT_TEST  1

## Notes

Remember to remove or unset this before going live; leaving it set means real
orders are never actually charged.

## See also

[MV_PAYMENT_MODE](MV_PAYMENT_MODE.md), the [payments](../guides/payments.md)
guide and the per-gateway pages under `../payments/`.

## Source

Consumed in `lib/Vend/Payment.pm` (`charge`, via `charge_param('test')`) using
`$::Variable->{MV_PAYMENT_TEST}`.
