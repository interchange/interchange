# MV_PAYMENT_MODE

Selects which payment gateway Interchange uses to process a charge. Reach for it
to name the payment module (and its route of settings) that the checkout charge
step should use.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_PAYMENT_MODE  gateway

`gateway` is the name of a payment gateway/route — for example `authorizenet`,
`testpayment`, or any other module under `lib/Vend/Payment/`. Default: unset (no
gateway).

## Description

When Interchange processes a charge it takes its base settings from a payment
*route* whose name is the charge type, then applies any options passed to the
[charge](../tags/charge.md) tag. `MV_PAYMENT_MODE` names that gateway/route, so
setting it selects the module that will authorize the transaction.

Interchange resolves individual payment parameters through `charge_param()`,
which checks the route's options first and then falls back to the variable
space. This means **any** payment parameter can be supplied as a variable named
`MV_PAYMENT_<NAME>`: `MV_PAYMENT_ID` supplies `id`,
[MV_PAYMENT_SECRET](MV_PAYMENT_SECRET.md) supplies `secret`, and so on. See the
individual pages and the per-gateway pages under `../payments/` for the
parameters a specific module reads.

## Examples

Use the built-in test gateway while developing:

    Variable  MV_PAYMENT_MODE  testpayment

Use an Authorize.Net route:

    Variable  MV_PAYMENT_MODE  authorizenet

## See also

[MV_PAYMENT_ID](MV_PAYMENT_ID.md), [MV_PAYMENT_SECRET](MV_PAYMENT_SECRET.md),
[MV_PAYMENT_CURRENCY](MV_PAYMENT_CURRENCY.md),
[MV_PAYMENT_PRECISION](MV_PAYMENT_PRECISION.md),
[MV_PAYMENT_TEST](MV_PAYMENT_TEST.md), [charge](../tags/charge.md),
the [payments](../guides/payments.md) guide and the `../payments/` reference.

## Source

Consumed in `lib/Vend/Payment.pm` (route selection and `charge_param`) via
`$::Variable->{MV_PAYMENT_MODE}`.
