# MV_PAYMENT_SECRET

Supplies the password or shared secret your payment gateway uses to authenticate
you. Reach for it to set the gateway's secret alongside
[MV_PAYMENT_ID](MV_PAYMENT_ID.md).

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_PAYMENT_SECRET  secret

The value is the gateway password, transaction key, or shared secret. Default:
unset.

## Description

`MV_PAYMENT_SECRET` is the variable-space source for the payment `secret`
parameter. When a gateway module calls `charge_param('secret')`, Interchange
returns the route option if set, otherwise the value of
`$::Variable->{MV_PAYMENT_SECRET}`.

## Examples

Set the gateway secret:

    Variable  MV_PAYMENT_SECRET  txn_key_abc123

## Notes

Treat this value as a credential. Keep it out of pages and out of version
control where possible; set it in a protected `catalog.cfg` or an included
secrets file.

## See also

[MV_PAYMENT_ID](MV_PAYMENT_ID.md), [MV_PAYMENT_MODE](MV_PAYMENT_MODE.md),
the [payments](../guides/payments.md) and [security](../guides/security.md)
guides.

## Source

Consumed in `lib/Vend/Payment.pm` (`charge_param('secret')`) and the gateway
modules under `lib/Vend/Payment/`, via `$::Variable->{MV_PAYMENT_SECRET}`.
