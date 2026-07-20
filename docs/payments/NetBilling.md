# NetBilling (Vend::Payment::NetBilling)

Charges cards or ACH/checking accounts through NetBilling's Direct Mode 2.1
HTTPS API. Supports address verification, authorize, sale, capture, credit,
and refund/void, for both card and check payment types.

## Prerequisites

`LWP::UserAgent`, `LWP::Protocol::https`, and `Digest::MD5`. A NetBilling
merchant or agent account and its Order Integrity Key.

## Configuration

    Require module Vend::Payment::NetBilling      # interchange.cfg

    Variable  MV_PAYMENT_MODE  netbilling          # catalog.cfg
    Route  netbilling  id      YourAccount:YourSiteTag
    Route  netbilling  secret  YourOrderIntegrityKey

| Option | Default | Meaning |
|---|---|---|
| `id` | (required) | `ACCOUNT:SITETAG` — your 12-character NetBilling account number and, where applicable, your site tag. Also settable as `MV_PAYMENT_ID`. |
| `secret` | (required) | Order Integrity Key, set in the NetBilling admin UI under Fraud Defense step 11. Also settable as `MV_PAYMENT_SECRET`. |
| `host` | `secure.netbilling.com` | NetBilling secure server. |
| `port` | (unset; standard HTTPS 443) | Port on the secure server. |
| `script` | `/gw/native/direct2.1` | Path to the Direct Mode 2.1 endpoint. |
| `getid` | `/gw/native/getid1.0` | Path to the pre-fetch-transaction-ID endpoint. |
| `poll` | `/gw/native/poll1.0` | Path to the transaction-status poll endpoint. |
| `retries` | `3` | Connection attempts before giving up, at each of the get-ID, submit, and poll steps. |
| `transaction` | `sale` | Transaction type; see below. |
| `type` | `mv_order_profile` value, else `charge` | Payment type: `K` or anything containing `check` selects ACH; anything else selects a card charge. |
| `trans_id` | (unset) | Prior NetBilling transaction ID; required to `settle`/capture, refund, or void a specific transaction. |
| `amount` | order total | Amount to charge; forced to `0.00` for `avs` transactions. |
| `remote_host`, `remote_ip` | session host/IP | Customer host/IP recorded with the transaction. |

## Values

These come from the order's standard address/card/check fields (billing
address defaults to shipping address when unset) and rarely need setting
directly: `address1`, `b_address1`, `city`, `b_city`, `state`, `b_state`,
`zip`, `b_zip`, `country`, `b_country`, `fname`/`b_fname`,
`lname`/`b_lname`, `email`, `phone_day`, `mv_credit_card_number`,
`mv_credit_card_exp_month`, `mv_credit_card_exp_year`,
`mv_credit_card_cvv2`, `check_account`, `check_routing`, `check_number`,
`check_ssn`, `check_dl`, `check_dl_state`, `check_taxid`, `auth_code`
(voice-authorization force code), `comment1` (up to 4000 chars), and
`item_desc` (defaults to a formatted dump of the cart).

## Transaction types

Set with the `transaction` option, default `sale`:

| Interchange | NetBilling `GEN_TRANS_TYPE` |
|---|---|
| `avs` | `AVS` — address verification only, no charge. |
| `auth`, `authorize` | `AUTH` — authorize for later capture. |
| `sale` | `SALE` — standard charge/ACH transaction. |
| `settle` | `CAPTURE` — capture a prior `AUTH` (needs `trans_id`). |
| `return` | `CREDIT` — credit the account instead of charging it. |
| `reverse`, `void` | `REFUND` — NetBilling decides internally whether to void or refund based on batch status. |
| `abort` | `ABORT` — abort a pending capture. |

## Testing

Use the test credit card number configured in NetBilling's
Setup/Account Config/Credit Cards admin page.

## Examples

Minimal card configuration:

    Require module Vend::Payment::NetBilling

    Variable  MV_PAYMENT_MODE  netbilling
    Route  netbilling  id      123456789012:mysite
    Route  netbilling  secret  myOrderIntegrityKey

Charging the order total through the route:

    [charge route="netbilling"]

## See also

[Payment processing concepts](../guides/payments.md), [charge](../tags/charge.md),
[Route](../config/Route.md).

## Source

`lib/Vend/Payment/NetBilling.pm`. The module's own POD documents the full
option and value list (`amount`, `getid`, `host`, `id`, `poll`, `port`,
`remap`, `remote_host`, `remote_ip`, `retries`, `script`, `secret`,
`trans_id`, `transaction`, `type`, and the customer/card/check value
fields); verified against the `netbilling()` routine.
