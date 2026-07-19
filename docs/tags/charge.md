# charge

Runs a payment transaction through a named payment route (gateway) and
returns the transaction identifier. Reach for it inside order routing or a
custom checkout page when you need to authorize, settle, or otherwise
charge a payment against the current order.

## Syntax

    [charge route attr=value ...]

Standalone tag (no end tag). The first positional argument is the payment
route name. Any additional named attributes are passed through to the
payment module as options.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `route`   | (none)  | Payment route name; also the default gateway. |

Positional order: `route`.

`[charge]` accepts arbitrary additional attributes (`addAttr`). Commonly
used ones include `gateway` (the payment module to invoke, defaulting to
the route name), `transaction` (the transaction type, such as `auth` or
`settle`), `amount` (overrides the order total), and `order_id`. The exact
set of meaningful options depends on the payment module named by the
route; see the [payments](../guides/payments.md) guide and the
`../payments/` reference pages.

## Description

Interchange Tag Language (ITL) is the template language processed on each
page. `[charge]` maps to the Perl routine `Vend::Payment::charge`, which:

1. Looks up a payment route with the same name as `route` in
   `Route`/`Route_repository`, using its settings as a base.
2. Overlays any attributes you passed on the tag.
3. Builds the amount from the tag's `amount` option or, by default, the
   current order total (`Vend::Interpolate::total_cost`), rounding to the
   configured precision and prefixing the currency
   (`MV_PAYMENT_CURRENCY`, the locale `currency_code`, or `usd`).
4. Dispatches to the gateway — either a `GlobalSub` named for the gateway
   or a `Vend::Payment::<gateway>` routine.

The gateway's result hash is stored in the session; the transaction
identifier the gateway returns is placed in the session as `payment_id`.
The tag itself returns that transaction identifier.

Because the amount and currency default from the order and configuration,
a bare `[charge routename]` is enough for the common case where a route
has been configured in `catalog.cfg`.

## Examples

Charge the current order total through a route named `authorizenet`:

    [charge authorizenet]

Run an explicit authorization for a specific amount and order id:

    [charge route=authorizenet transaction=auth amount=19.95 order_id=[value mv_order_number]]

In practice `[charge]` is usually called from an order profile or the
`route` `payment_mode`, not typed directly on a storefront page. See the
[payments](../guides/payments.md) and
[cart-and-checkout](../guides/cart-and-checkout.md) guides.

## Notes

The tag returns a transaction identifier, not a success flag. Check the
session result hash (`$Session->{payment_result}`) for the gateway's
`MStatus`/`pop.status` fields to determine whether the charge succeeded.

## See also

[order](order.md), [price](price.md), the
[payments](../guides/payments.md) guide,
[MV_PAYMENT_CURRENCY](../variables/MV_PAYMENT_CURRENCY.md),
[MV_PAYMENT_PRECISION](../variables/MV_PAYMENT_PRECISION.md).

## Source

Defined in `code/SystemTag/charge.coretag`. Implemented by
`Vend::Payment::charge` in `lib/Vend/Payment.pm`.
