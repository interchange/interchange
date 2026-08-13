# AuthorizeNet (Vend::Payment::AuthorizeNet)

Charges, credits, and voids transactions through the Authorize.Net payment
gateway using its version 3 "AIM" (Advanced Integration Method, formerly "ADC
Direct Response") API. It supports both credit card and eCheck transactions
and can capture, authorize-only, void, or credit a prior transaction.

## Prerequisites

- `Net::SSLeay`, or `LWP::UserAgent` with `Crypt::SSLeay` (only one pair is
  required).
- An Authorize.net merchant account: login ID and transaction key (or
  password).

## Configuration

    Require module Vend::Payment::AuthorizeNet    # interchange.cfg
    Variable MV_PAYMENT_MODE authorizenet         # catalog.cfg
    Route  authorizenet  id       YourAuthorizeNetID
    Route  authorizenet  secret   YourAuthorizeNetSecret

Make sure `CreditCardAuto` is off (the default in the Interchange demos).
The mode name can be anything, but the `gateway` parameter (or the mode name
itself, since it defaults to the charge type) must resolve to `authorizenet`.

Every setting below is read through `charge_param()`: first from the options
passed to `[charge ...]`/`&charge`, then from a `Route` of the same name as
the mode, then from a `Variable MV_PAYMENT_*` of the same name.

| Option                | Default                  | Meaning |
|------------------------|--------------------------|---------|
| `id`                   | none (required)          | Authorize.net login ID (`MV_PAYMENT_ID`). |
| `secret`               | none                     | Authorize.net transaction key or password (`MV_PAYMENT_SECRET`); sent as `x_Password` unless `use_transaction_key` is set, in which case it is sent as `x_Tran_Key`. |
| `host`                 | `secure.authorize.net`   | Gateway hostname. Authorize.net recommends `secure2.authorize.net` (their Akamai host). |
| `referer`              | none                     | HTTP `Referer` header value; must match the referrer(s) allowed on the account (`MV_PAYMENT_REFERER`). |
| `transaction`          | `sale`                   | Requested transaction type; see [Transaction types](#transaction-types). |
| `method`               | `CC`                     | `CC` for credit card or `ECHECK` for electronic check. |
| `remap`                | none                     | Remaps standard field names to others; see `map_actual()` in [Vend::Payment](../guides/payments.md). |
| `test`                 | none                     | If true, sets Authorize.net's `x_Test_Request` flag. |
| `accept_for_review`    | none                     | If true, an Authorize.net response code of `4` ("Held for Review", e.g. fraud-score holds) is treated as success instead of failure. |
| `use_transaction_key`  | none                     | Send `secret` as `x_Tran_Key` instead of `x_Password`. |
| `message_avs`          | built-in English text    | Error message template used when the AVS street-address check fails (`x_avs_code eq 'N'`). |
| `message_declined`     | built-in English text    | Error message template used for any other decline. |
| `gwl_enabled`          | false                    | Enable [GatewayLog](GatewayLog.md) transaction logging. |
| `gwl_table`            | `gateway_log`            | Table `GatewayLog` writes to. |
| `gwl_source`           | `` `hostname -s` `` output | Value stored in the log's `request_source` column. |

`script` (`/gateway/transact.dll`) and `port` (`443`) can also be overridden
via the option hash passed to the `authorizenet()` routine itself (e.g. from
a `GlobalSub`), but they are not read through `charge_param()` and so cannot
be set with `Route`/`Variable`.

## Transaction types

The `transaction` option (or the historical `mv_payment_mode`/`cyber_mode`
value) maps to Authorize.net's `x_Type` values:

| Interchange       | Authorize.net        |
|-------------------|-----------------------|
| `auth`, `authorize`, `mauthonly` | `AUTH_ONLY` |
| `sale`, `mauthcapture` (default) | `AUTH_CAPTURE` |
| `settle`          | `CAPTURE_ONLY` |
| `settle_prior`    | `PRIOR_AUTH_CAPTURE` |
| `return`          | `CREDIT` |
| `void`            | `VOID` |

With `method=ECHECK`, only `AUTH_CAPTURE`, `CREDIT`, and `VOID` are valid;
the module logs a warning (does not fail) if an unrecognized combination of
`method` and transaction type is requested.

## Testing

Set `test=TRUE` (via `Route`, `Variable MV_PAYMENT_TEST`, or the `[charge]`
call) to send `x_Test_Request=TRUE` to Authorize.net's live/test endpoint.
With test mode off, Authorize.net's documented test card numbers can be used
against a test-mode merchant account, e.g. `4222222222222222` to exercise
various decline paths, or `4111111111111111` to get a clean decline useful
for confirming `[data session payment_error]` is populated.

## Examples

Minimal `catalog.cfg` fragment:

    Variable MV_PAYMENT_MODE authorizenet
    Route  authorizenet  id       YourAuthorizeNetID
    Route  authorizenet  secret   YourAuthorizeNetSecret

Charging the current order total from a checkout page:

    [charge mode="authorizenet" interaction="charge"]

Authorize only, then capture later against the same transaction:

    [charge mode="authorizenet" transaction="auth"]
    ...
    [charge mode="authorizenet" transaction="settle_prior" order_id="123456"]

Enabling full transaction logging to the `gateway_log` table:

    Route  authorizenet  gwl_enabled  1

## See also

[Payment processing concepts](../guides/payments.md), [GatewayLog](GatewayLog.md).

## Source

`lib/Vend/Payment/AuthorizeNet.pm` (has its own POD). Uses
[Vend::Payment::GatewayLog](GatewayLog.md) for optional transaction logging.
