# Braintree (Vend::Payment::Braintree)

Charges, voids, refunds, and looks up transactions through the Braintree
gateway (a PayPal company) using the `Net::Braintree` client library. It
also supports Braintree's vaulted-customer/payment-method-token flow and can
issue client tokens for front-end (drop-in UI) integrations.

## Prerequisites

- `Net::Braintree` (from CPAN).
- A Braintree account: `merchant_id`, `public_key`, and `private_key`.

## Configuration

    Require module Vend::Payment::Braintree       # interchange.cfg
    Variable MV_PAYMENT_MODE braintree            # catalog.cfg
    Route  braintree  merchant_id   YourMerchantID
    Route  braintree  public_key    YourPublicKey
    Route  braintree  private_key   YourPrivateKey
    Route  braintree  environment   sandbox

Every setting is read the same way as other payment modules: `[charge]`
option, then `Route`, then `Variable MV_PAYMENT_*`.

| Option                         | Default | Meaning |
|--------------------------------|---------|---------|
| `merchant_id`                  | none (required) | Supplied by Braintree. |
| `public_key`                   | none (required) | Supplied by Braintree. |
| `private_key`                  | none (required) | Supplied by Braintree. |
| `environment`                  | none (required) | One of `sandbox`, `integration`, `development`, `qa`, or `production`. |
| `transaction`                  | `A` (auth)       | Requested transaction; see [Transaction types](#transaction-types). |
| `payment_method_nonce`         | none    | Single-use token from Braintree's client-side integration identifying a payment instrument. |
| `payment_method_token`         | none    | Permanent vault token for a payment instrument. Preferred over `payment_method_nonce` when both are present. |
| `comment1`                     | none    | Interchange order number or other local identifier, passed to Braintree as `order_id` and stored in the log's `order_number` column. |
| `order_id`                     | none    | Prior transaction ID, for follow-on `settle`/`void`/`find` calls. |
| `check_sub`                    | none    | Name of a `Sub`/`GlobalSub` used to post-process the raw `Net::Braintree` result; called as `$sub->($result, $transtype)` and must return true/false to accept or reject an otherwise-successful transaction. |
| `custom_fields`                | none    | Passed through to Braintree as-is. |
| `device_data`                  | none    | Passed through to Braintree as-is (fraud/device fingerprint data). |
| `merchant_account_id`          | none    | Selects a specific Braintree sub-merchant account. |
| `skip_advanced_fraud_checking` | none    | Passed through as a Braintree transaction option. |
| `precision`                    | `2`     | Decimal places used when computing the amount from the cart total. |
| `gwl_enabled`                  | false   | Enable [GatewayLog](GatewayLog.md) transaction logging. |
| `gwl_table`                    | `gateway_log` | Table `GatewayLog` writes to. |
| `gwl_source`                   | `` `hostname -s` `` output | Value stored in the log's `request_source` column. |

There is no `test` option; whether transactions are live or sandboxed is
controlled entirely by `environment`.

## Transaction types

    Interchange              Braintree letter    Net::Braintree call
    ------------------------ ------------------- -----------------------
    sale                     S                   Transaction->sale (submit_for_settlement)
    auth, authorize          A                   Transaction->sale (auth only)
    settle, settle_prior     D                   Transaction->submit_for_settlement
    void                     V                   Transaction->void
    credit                   C                   Transaction->refund
    mini_auth, verify        M                   Customer->create (card verification)
    status, find             F                   Transaction->find
    client_token, token      T                   Net::Braintree::ClientToken->generate

The single-letter Braintree-style codes (`A`, `S`, `D`, `V`, `C`, `M`, `F`,
`T`) are also accepted directly. Default transaction is `A`.

> **POD/code note:** the module's own POD documents `return` as the
> Interchange name mapping to Braintree's `C` (credit/refund) transaction.
> In the current code's `%type_map`, that name is `credit` (and `verify`),
> not `return` — `transaction=return` is rejected with "Unrecognized
> transaction: return". Use `credit` to issue a refund.

`mini_auth`/`M` runs a card-verification-only "customer" call; its result's
transaction ID is a `payment_method_token` for later use, returned as the
scalar from `$Tag->charge` or via `[data session payment_id]`.
`client_token`/`T` returns a client token (for browser-side Braintree.js
integration) as that same scalar value, rather than performing a charge.

## Testing

Set `environment` to `sandbox` and use Braintree's published sandbox nonces
(e.g. `fake-valid-nonce`) or sandbox test card numbers through your
front-end integration; there is no separate `test` flag.

## Examples

Minimal `catalog.cfg` fragment:

    Variable MV_PAYMENT_MODE braintree
    Route  braintree  merchant_id  YourMerchantID
    Route  braintree  public_key   YourPublicKey
    Route  braintree  private_key  YourPrivateKey
    Route  braintree  environment  sandbox

Sale using a client-supplied nonce:

    [charge mode="braintree" transaction="sale" payment_method_nonce="[cgi payment_method_nonce]"]

Authorize now, capture later against the resulting transaction ID:

    [charge mode="braintree" transaction="auth" payment_method_nonce="[cgi nonce]"]
    ...
    [charge mode="braintree" transaction="settle_prior" order_id="[data session payment_id]"]

Issue a refund against a previously-settled transaction:

    [charge mode="braintree" transaction="credit" order_id="a1b2c3"]

## See also

[Payment processing concepts](../guides/payments.md), [GatewayLog](GatewayLog.md).

## Source

`lib/Vend/Payment/Braintree.pm` (has its own POD). Uses
[Vend::Payment::GatewayLog](GatewayLog.md) (as `Vend::Payment::Braintree::GWL`)
for optional transaction logging.
