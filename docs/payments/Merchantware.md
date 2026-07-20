# Merchantware (Vend::Payment::Merchantware)

Charges cards through Merchant Warehouse's Merchantware SOAP API (Retail
Transaction v4). Supports sale, auth/capture, refund, void, repeat sale by
token, and Level 2 (purchasing-card) sales.

## Prerequisites

`SOAP::Lite`. A Merchant Warehouse account with a site ID, key, and
merchant/partner name.

## Configuration

    Require module Vend::Payment::Merchantware       # interchange.cfg

    Variable  MV_PAYMENT_MODE  merchantware           # catalog.cfg
    Route  merchantware  id       YourMerchantwareID
    Route  merchantware  secret   YourAccountKey
    Route  merchantware  partner  YourAccountName

| Option | Default | Meaning |
|---|---|---|
| `id` | (required) | Merchant Warehouse site ID (`merchantSiteId`). Also settable as `MV_PAYMENT_ID`. |
| `secret` | (required) | Account key, not a password (`merchantKey`). Also settable as `MV_PAYMENT_SECRET`. |
| `partner` | (required) | Account/merchant name (`merchantName`). Also settable as `MV_PAYMENT_PARTNER`. |
| `test` | (unset) | Set to `TRUE` to use `staging.merchantware.net` instead of `ps1.merchantware.net`. |
| `precision` | `2` | Decimal places used when rounding the order total if no explicit amount is supplied. |
| `check_sub` | (unset) | Name of a `Sub`/`GlobalSub` called with the result hash and transaction type after an `APPROVED` response, used to fail orders on bad AVS since Merchantware itself never declines for that. Return true to accept, false to fail. |
| `remap` | (unset) | Remaps standard form-variable names to the ones Merchantware expects; rarely needed. |

## Transaction types

Set with the `transaction` option, default `sale`:

| Interchange | Merchantware method |
|---|---|
| `sale`, `mauthcapture` | `SaleKeyed` |
| `auth`, `authorize` | `PreAuthorizationKeyed` |
| `credit`, `refund`, `return` | `Refund` |
| `void`, `reverse` | `Void`, or `VoidPreAuthorization` whenever the generated order id is non-empty |
| `settle`, `settle_prior` | `PostAuthorization` |
| `repeat_sale` | `RepeatSale` (from a previous sale/auth token) |
| `settle_batch` | `SettleBatch` |
| `level2_sale` | `Level2SaleKeyed` |

`credit`, `void`, `settle`, and `repeat_sale` operate on the token returned
by a prior transaction, which the module tracks by appending it to
`pop.auth-code` (`auth-code,token`) and splitting it back out on the next
call.

Note: the code's `void` &rarr; `void_auth` check tests only that the
generated order id is non-empty (`$order_id =~ /\w+\z/`), and an order id
is always generated before this check runs. In practice a plain `void`
therefore resolves to `VoidPreAuthorization` (Merchantware's
`void_auth`); reaching the plain `Void` method appears to require an
explicit empty `order_id`. Verified from the code; the intent behind this
condition is not documented.

## Testing

Set `test` to `TRUE` (as a `Route` or `Variable MV_PAYMENT_TEST`, or a tag
option) to post to Merchant Warehouse's staging endpoint. Then try a sale
with card number `4111 1111 1111 1111` and a valid future expiration date;
it should be denied, with the reason in `[data session payment_error]`.

## Examples

Minimal configuration:

    Require module Vend::Payment::Merchantware

    Variable  MV_PAYMENT_MODE  merchantware
    Route  merchantware  id       YourMerchantwareID
    Route  merchantware  secret   YourAccountKey
    Route  merchantware  partner  YourAccountName

Auth now, capture later, with an AVS check on the initial auth:

    Route  merchantware  transaction  auth
    Route  merchantware  check_sub    mw_check

    GlobalSub <<EOR
    sub mw_check {
        my ($result, $transtype) = @_;
        return 1 unless $transtype eq 'auth';
        my ($avs, $cvv) = @{$result}{qw( AvsResponse CvResponse )};
        return 1 if $avs =~ /^[XYAZWUG RS BDMP]$/;
        return 1 if $cvv =~ /^[MPSUX]$/;
        $result->{MStatus} = 'failure';
        $result->{ErrorMessage} = "The billing address you entered does not match.";
    }
    EOR

Charging the order total through the route:

    [charge route="merchantware"]

## See also

[Payment processing concepts](../guides/payments.md), [charge](../tags/charge.md),
[Route](../config/Route.md).

## Source

`lib/Vend/Payment/Merchantware.pm` (module POD documents `id`, `secret`,
`partner`, `transaction`, `check_sub`, `remap`, and `test`; verified
against the `merchantware()` routine, which also reads `precision`).
