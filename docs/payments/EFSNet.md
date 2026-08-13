# EFSNet (Vend::Payment::EFSNet)

Charges, authorizes, settles, credits, and voids transactions through
Concord EFSNet (`efsnet.concordebiz.com`), using a name/value-pair HTTPS
POST protocol modeled closely on the [AuthorizeNet](AuthorizeNet.md) driver
it was adapted from.

## Prerequisites

- `Net::SSLeay`, or `LWP::UserAgent` with `Crypt::SSLeay` (only one pair is
  required).
- An EFSNet Store ID and Store Key, from the Merchant Services panel at
  Concord's site.

## Configuration

    Require module Vend::Payment::EFSNet          # interchange.cfg
    Variable MV_PAYMENT_MODE efsnet                # catalog.cfg
    Route  efsnet  id       YourEFSNetStoreID
    Route  efsnet  secret   YourEFSNetStoreKey

Make sure `CreditCardAuto` is off. Every setting is read through
`charge_param()` unless noted otherwise: `[charge]` option, then `Route`,
then `Variable MV_PAYMENT_*`.

| Option              | Default                       | Meaning |
|---------------------|--------------------------------|---------|
| `id`                | none (required)                | EFSNet Store ID (`MV_PAYMENT_ID`). |
| `secret`            | none                            | EFSNet Store Key (`MV_PAYMENT_SECRET`). |
| `transaction`       | `sale`                          | Requested transaction type; see [Transaction types](#transaction-types). |
| `remap`             | none                            | Remaps standard field names to others; see `map_actual()` in [Vend::Payment](../guides/payments.md). |
| `original_amount`   | current computed amount        | For partial `settle`/`return` transactions, the amount of the *original* charge — EFSNet requires this in addition to the (possibly smaller) amount being settled or refunded. |
| `message_avs`       | built-in English text          | Error message template used when the AVS check fails (`AVSResponseCode eq 'N'`). Not listed in the module's "active settings" POD section. |
| `message_declined`  | built-in English text          | Error message template used for any other decline. Not listed in the module's "active settings" POD section. |

`host` (default `efsnet.concordebiz.com`), `script`
(`/efsnet.dll`), and `port` (`443`) can be overridden, but **only** via a
`Route`/option key of the same name read directly as `$opt->{host}` etc. —
they are not passed through `charge_param()`, so a bare `Variable
MV_PAYMENT_HOST` has no effect on them.

> **POD/code note:** the module's own troubleshooting section says to
> enable the test servers with `MV_PAYMENT_HOST testefsnet.concordebiz.com`
> (a `Variable`). The code only reads `$opt->{host}` directly (no
> `charge_param('host')` call), so that `Variable` is not actually consulted
> — use `Route efsnet host testefsnet.concordebiz.com` instead to switch to
> the test host.

## Transaction types

| Interchange                     | EFSNet method |
|-----------------------------------|-----------------|
| `sale`, `mauthcapture` (default)   | `CreditCardCharge` |
| `auth`, `authorize`, `mauthonly`   | `CreditCardAuthorize` |
| `settle`, `settle_prior`          | `CreditCardSettle` |
| `return`                          | `CreditCardRefund` |
| `void`                            | `VoidTransaction` |

`settle` and `return` also send `OriginalTransactionID` (from
`auth_code`/`order_id`) and `OriginalTransactionAmount`; `void` sends
`TransactionID`; a capture-only path additionally sends
`AuthorizationNumber`.

> **POD/code contradiction:** the module's POD lists `reverse` as mapping to
> `CreditCardRefund`, but the code's `%type_map` has no `reverse` entry. A
> `transaction=reverse` call is passed through to EFSNet unmodified as the
> literal method name `reverse`, which EFSNet does not recognize — it does
> not actually behave as a refund. Use `return` for refunds.

`CreditCardCredit` transactions (crediting a card without referencing a
prior charge) are supported by the module but disabled by default on new
EFSNet accounts; contact EFSNet to enable it if needed.

## Testing

Point at EFSNet's test host with `Route efsnet host
testefsnet.concordebiz.com` (see the note above — the `MV_PAYMENT_HOST`
variable documented in the module's POD does not work) and use the test
card number `4111 1111 1111 1111`.

## Examples

Minimal `catalog.cfg` fragment:

    Variable MV_PAYMENT_MODE efsnet
    Route  efsnet  id      YourEFSNetStoreID
    Route  efsnet  secret  YourEFSNetStoreKey

Charging the current order total:

    [charge mode="efsnet" interaction="charge"]

Partial refund, telling EFSNet the original charge amount:

    [charge mode="efsnet" transaction="return" amount="10.00" original_amount="49.95" order_id="[data session payment_id]"]

## See also

[Payment processing concepts](../guides/payments.md), [AuthorizeNet](AuthorizeNet.md).

## Source

`lib/Vend/Payment/EFSNet.pm` (has its own POD).
