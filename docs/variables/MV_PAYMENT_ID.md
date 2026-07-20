# MV_PAYMENT_ID

Supplies the merchant/account identifier your payment gateway uses to recognize
you. Reach for it to set the login or merchant ID for the selected gateway.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_PAYMENT_ID  merchant-id

The value is whatever identifier the gateway expects (merchant ID, login, API
user). Default: unset.

## Description

`MV_PAYMENT_ID` is the variable-space source for the payment `id` parameter.
When a gateway module calls `charge_param('id')`, Interchange returns the route
option if set, otherwise the value of `$::Variable->{MV_PAYMENT_ID}`. Most
gateway modules use this as the account/login identifier.

## Examples

Set the merchant ID for the active gateway:

    Variable  MV_PAYMENT_ID  my_merchant_login

## See also

[MV_PAYMENT_MODE](MV_PAYMENT_MODE.md),
[MV_PAYMENT_SECRET](MV_PAYMENT_SECRET.md), the
[payments](../guides/payments.md) guide.

## Source

Consumed in `lib/Vend/Payment.pm` (`charge_param('id')`) and the gateway modules
under `lib/Vend/Payment/`, via `$::Variable->{MV_PAYMENT_ID}`.
