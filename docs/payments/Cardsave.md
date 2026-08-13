# Cardsave (Vend::Payment::Cardsave)

Charges credit cards through Cardsave (thepaymentgateway.net, a UK acquirer)
using its SOAP/XML `CardDetailsTransaction` API, including full 3-D Secure
(3DS) cardholder authentication with a bounce out to the card issuer's ACS
(Access Control Server) page and back. It also supports card-type lookup and
cross-reference (token-based) repeat/refund/void operations for a virtual
terminal.

Unlike most payment modules, Cardsave is not a single self-contained call:
a normal sale is a multi-request flow across two or three storefront pages,
because 3DS requires redirecting the customer's browser to their bank and
back before the transaction can complete.

## Prerequisites

- `XML::Simple`
- `URI`
- `libwww-perl` (`LWP`, `HTTP::Request`, `HTTP::Request::Common`)
- `Net::SSLeay`
- A Cardsave merchant ID and password.
- Three new pages in `pages/ord/` (`tdscardsavereturn.html`, `tdsfinal.html`,
  `tdsauth.html`) to carry the browser through the 3DS round trip, plus
  changes to `etc/log_transaction.html` and `etc/profiles.order` — see
  [Examples](#examples) and the module's own POD for the exact snippets.

## Configuration

    Require module Vend::Payment::Cardsave              # interchange.cfg
    Variable MV_PAYMENT_MODE cardsave                   # catalog.cfg
    Route  cardsave  id         xxx
    Route  cardsave  password   xxx
    Route  cardsave  returnurl  'https://domain.tld/cgi/ord/tdscardsavereturn'

All options are read through `charge_param()`: `[charge]`/route option
first, `Route cardsave ...` second (there is no `Variable MV_PAYMENT_*`
fallback path exercised for most of these — the module calls
`charge_param()` directly, which does still fall back to
`MV_PAYMENT_<NAME>` for any name not found in the route).

| Option                        | Default                                    | Meaning |
|--------------------------------|---------------------------------------------|---------|
| `id`                           | none (required, dies without it)             | Cardsave `MerchantID`. |
| `password`                     | none (required, dies without it)             | Cardsave merchant password. |
| `returnurl`                    | `$SECURE_SERVER$CGI_URL/ord/tdscardsavereturn` | 3DS `TermUrl`: where the issuer's ACS redirects the browser back to. |
| `cardsaverequest`              | `cardpost`                                   | Which sub-operation to run this call: `cardpost` (initial sale), `tdspost` (after the ACS bounce), `getcardtype`, `getgatewayentrypoints`, or `crossreferencepost`. Normally driven by hidden form fields, not set by hand. |
| `txtype`                       | `SALE`                                       | Transaction type sent as `TransactionType`; also used as the virtual-terminal op (`SALE`, `PREAUTH`, `COLLECTION`, `REFUND`, `VOID`). |
| `tdsfinalpage`                 | `ord/tdsfinal`                                | Page the customer is redirected to (via `[area]`) to host the ACS iframe while 3DS runs. |
| `currency`                     | `GBP` (falls back through scratch/values first) | ISO currency; mapped internally to Cardsave's numeric ISO code (826 GBP, 978 EUR, 840 USD, else looked up in the `country` table). |
| `host1`..`host4`               | Cardsave's four `gw#.cardsaveonlinepayments.com:4430` endpoints | Override individual gateway entry points. `host4` is noted in the code as testing-only (does not resolve). |
| `echocardtype`                 | `TRUE`                                        | Cardsave `TransactionControl` flag. |
| `echoavscheckresult`           | `TRUE`                                        | Cardsave `TransactionControl` flag. |
| `echocv2checkresult`           | `TRUE`                                        | Cardsave `TransactionControl` flag. |
| `echoamountreceived`           | `TRUE`                                        | Cardsave `TransactionControl` flag. |
| `duplicatedelay`               | `1`                                           | Cardsave duplicate-transaction detection window, in seconds. |
| `avsoverridepolicy`            | `NPPP` (overridable per-request via `[value avs_override_policy]`) | Cardsave AVS override policy string. |
| `cv2overridepolicy`            | `PP` (overridable per-request via `[value cv2_override_policy]`) | Cardsave CV2 override policy string. |
| `threedsecureoverridepolicy`   | `TRUE` (overridable per-request via `[value tds_override_policy]`) | `TRUE` forces 3DS on, `FALSE` turns it off. |
| `main3DSerror`                 | `"Payment error: <br>"`                       | Prefix used for the customer-facing error message on decline. |
| `mail_txn_to`                  | `$Variable->{ORDERS_TO}`                      | Address used for the optional approved/declined notification emails. |
| `mail_txn_approved`            | none                                          | If `1`, emails `mail_txn_to` on a successful transaction. |
| `mail_txn_declined`            | none                                          | If `1`, emails `mail_txn_to` when the failure message matches `/avs\|declined\|variable/i`. |
| `psp`                          | `Cardsave`                                   | Stored into `$::Values->{psp}` on success, for use as a `transactions` table field. |
| `order_id`                     | generated timestamp + session id             | Only consulted for `crossreferencepost` operations. |

> **POD/code contradictions found:**
> - The module's setup instructions document `Route cardsave address_error`,
>   `Route cardsave postcode_error`, and `Route cardsave cv2_error` as ways
>   to override the AVS/postcode/CV2 failure messages. None of the three is
>   read anywhere in the code (no `charge_param('address_error')` etc.
>   exists); the actual messages are hard-coded English strings ("Billing
>   Address ... failed to match at your bank", etc.) and cannot currently be
>   overridden.
> - The line meant to suppress the CV2-mismatch message when
>   `cv2overridepolicy` starts with `P` checks
>   `charge_param('cv2ovreridepolicy')` — misspelled in the source — so it
>   always reads as unset and that message is never suppressed regardless of
>   the actual `cv2overridepolicy` setting.

## Transaction types

`txtype` (default `SALE`) is sent directly as Cardsave's `TransactionType`
for a card-present sale, and doubles as the virtual-terminal operation for
`crossreferencepost` calls: `SALE`, `PREAUTH`, `COLLECTION`, `REFUND`, or
`VOID`, keyed to the `MD` cross-reference value saved from the original 3DS
transaction (stored as the `md` column in the `transactions` table).

## Testing

Cardsave publishes fixed test card numbers that must be used against a test
merchant account:

| Card                    | Expected result |
|-------------------------|-----------------|
| `4976000000003436`, CV2 `452`, no 3DS, street no. 32, postcode `TR148PA`, exp `12/12` | success |
| `4976350000006891`, CV2 `341`, with 3DS, street no. 113, postcode `B421SX`, exp `12/12` | success |
| Any other CV2 or postcode value | failure |

## Examples

Minimal `catalog.cfg` fragment:

    Variable MV_PAYMENT_MODE cardsave
    Route  cardsave  id         xxx
    Route  cardsave  password   xxx
    Route  cardsave  returnurl  'https://domain.tld/cgi/ord/tdscardsavereturn'

`pages/ord/tdscardsavereturn.html` (the browser lands here after the bank's
ACS redirects back):

    [charge route="cardsave" cardsaverequest="tdspost"]

`pages/ord/tdsauth.html` (auto-submits the customer to their bank's ACS):

    <body onload="document.form.submit();">
    <form name="form" action="[scratchd acsurl]" method="POST">
    <input type="hidden" name="PaReq" value="[scratch pareq]">
    <input type="hidden" name="TermUrl" value="[scratch termurl]">
    <input type="hidden" name="MD" value="[scratch md]">
    </form>

Overriding the default AVS/CV2 override policy:

    Route cardsave avsoverridepolicy NPPP
    Route cardsave cv2overridepolicy PP

## See also

[Payment processing concepts](../guides/payments.md).

## Source

`lib/Vend/Payment/Cardsave.pm` (has its own POD with detailed integration
instructions covering pages, `etc/log_transaction`, and `etc/profiles.order`
changes not repeated in full here).
