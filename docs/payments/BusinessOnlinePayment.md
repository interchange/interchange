# BusinessOnlinePayment (Vend::Payment::BusinessOnlinePayment)

Generic wrapper around the CPAN `Business::OnlinePayment` framework, letting
Interchange drive any gateway that has a `Business::OnlinePayment::*` backend
module (dozens exist) through one Interchange payment module. Useful when no
native `Vend::Payment::*` driver exists for your processor.

## Prerequisites

- `Business::OnlinePayment` (core dispatcher).
- The specific `Business::OnlinePayment::<Processor>` module for your
  gateway (installed separately from CPAN).

## Configuration

    Require module Vend::Payment::BusinessOnlinePayment   # interchange.cfg
    Variable MV_PAYMENT_MODE onlinepayment                # catalog.cfg
    Route  onlinepayment  processor  SomeProcessor
    Route  onlinepayment  id        YourLogin
    Route  onlinepayment  secret    YourPassword

The mode can be named anything, but the `gateway` parameter must resolve to
`onlinepayment`. Every setting is read through `charge_param()`: `[charge]`
option, then `Route`, then `Variable MV_PAYMENT_*`.

| Option                | Default | Meaning |
|-----------------------|---------|---------|
| `processor`           | none (required) | The `Business::OnlinePayment::<processor>` name, passed as the first argument to `Business::OnlinePayment->new`. |
| `id`                  | none (required) | Login for the underlying gateway (`MV_PAYMENT_ID`). |
| `secret`              | none    | Password for the underlying gateway (`MV_PAYMENT_SECRET`). |
| `transaction`         | `sale`  | Requested transaction; see [Transaction types](#transaction-types). |
| `test`                | none    | Passed to `$transaction->test_transaction(...)`. Only meaningful if your specific `Business::OnlinePayment::*` backend supports test mode. |
| `precision`           | `2`     | Decimal places used when computing the amount from the cart total. |
| `referer`             | none    | Passed through to the backend as a `referer` content field. |
| `extra_query_params`  | none    | Space/comma-separated list mapping request parameters through to the backend's `content()` call; see below. |
| `extra_result_params` | none    | Space/comma-separated list mapping backend result methods into the Interchange result hash; see below. |

**Any other option** — set via `[charge]`, `Route`, or `Variable
MV_PAYMENT_*` — that is not `gateway`, `processor`, `id`, `secret`, or
`transaction` is passed straight through as a `Business::OnlinePayment->new`
constructor option. Consult your specific backend module's documentation for
what it accepts.

`extra_query_params` maps a parameter through to the gateway's
`content()` call:

    Route onlinepayment extra_query_params "customer_id their_param=our_param"

This passes `customer_id` through under its own name, and passes the value
of option `our_param` under the gateway's expected key `their_param`.

`extra_result_params` maps a `Business::OnlinePayment` result-object method
into the Interchange result hash, only if the backend object supports that
method:

    Route onlinepayment extra_result_params "transid=avs_code"

This stores `$transaction->avs_code` (if the method exists) as
`$result{transid}`.

> **Note:** the module accepts a `message_avs` option intended to customize
> the AVS-failure error message, matching the pattern used by other gateway
> drivers, but the code path that would use it is gated behind `if (0)` and
> never runs (see `lib/Vend/Payment/BusinessOnlinePayment.pm`, the comment
> "need a standard Business::OnlinePayment way to ask about AVS"). All
> failures currently produce the `message_declined` message regardless of
> cause.

## Transaction types

| Interchange | Business::OnlinePayment action |
|-------------|----------------------------------|
| `sale` (default) | Normal Authorization |
| `auth`      | Authorization Only |
| `settle`    | Post Authorization |
| `return`    | Credit |
| `void`      | Void |

There is no mapping for `reverse` (a placeholder comment exists in the code
but no action is defined for it).

## Testing

Set `test` true and confirm your specific `Business::OnlinePayment::*`
backend module actually implements a test mode — not all of them do.

## Examples

Minimal `catalog.cfg` fragment (using the `AuthorizeNet` Business::OnlinePayment
backend, distinct from the native [AuthorizeNet](AuthorizeNet.md) module):

    Variable MV_PAYMENT_MODE onlinepayment
    Route  onlinepayment  processor  AuthorizeNet
    Route  onlinepayment  id         YourLogin
    Route  onlinepayment  secret     YourPassword

Charging the current order total:

    [charge mode="onlinepayment" interaction="charge"]

Passing a processor-specific option through the constructor (e.g. a
`server` option some backends accept):

    Route onlinepayment server test.example.com

## See also

[Payment processing concepts](../guides/payments.md).

## Source

`lib/Vend/Payment/BusinessOnlinePayment.pm` (has its own POD).
