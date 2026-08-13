# PaypalExpress (Vend::Payment::PaypalExpress)

Charges cards through PayPal Express Checkout using PayPal's classic SOAP
API (`NVPCheckout`/`eBLBaseComponents`), driving the Set/Get/Do request
sequence PayPal Express Checkout requires, plus its recurring-billing
(`CreateRecurringPaymentsProfile`), refund, MassPay, IPN, and virtual
terminal operations.

This module is unusually deep and mostly self-contained: rather than a
single `transaction` attribute, each call selects an operation with the
`pprequest` attribute, and a large catalog integration (order-profile and
`etc/log_transaction` edits) is needed to co-operate with another gateway
for non-PayPal payments. This page covers the standard Express Checkout
flow and the main configuration; see the module's own POD (`perldoc
Vend::Payment::PaypalExpress` or the source) for the full checkout-page
walkthrough and every recurring-billing/admin field.

## Prerequisites

`SOAP::Lite`, `XML::Parser`, `MIME::Base64`, `URI`, `libwww-perl`,
`Crypt::SSLeay`, `IO::Socket::SSL` (0.97, or 0.99x+ once its "illegal seek"
bug is fixed), and `Date::Calc`. A PayPal Business account with API
credentials (username/password/signature) generated under Profile ->
API Access -> Request API Credentials -> Signature.

## Configuration

    Require module Vend::Payment::PaypalExpress    # interchange.cfg

    Variable  MV_PAYMENT_MODE  paypalexpress        # catalog.cfg
    Route  paypalexpress  id         xxx
    Route  paypalexpress  password   xxx
    Route  paypalexpress  signature  xxx
    Route  paypalexpress  returnurl  __SECURE_SERVER____CGI_URL__/ord/paypalgetrequest
    Route  paypalexpress  cancelurl  __SECURE_SERVER____CGI_URL__/__CHECKOUT_PAGE__
    Route  paypalexpress  host       api-3t.paypal.com

| Option | Default | Meaning |
|---|---|---|
| `id`, `password`, `signature` | (required) | API credentials. May be prefixed (e.g. `gbp_id`, `usd_id`) to switch credential sets by currency/account — see Multiple accounts below. |
| `returnurl` | (required) | Where PayPal returns the buyer after approval. |
| `cancelurl` | (required) | Where PayPal sends the buyer if they cancel. |
| `host` | `api-3t.paypal.com` | API host; use `api-3t.sandbox.paypal.com` for the sandbox, or set `sandbox`/`ppsandbox` to switch automatically. |
| `sandbox` | (unset) | Truthy value (or `1`) selects the sandbox host and, if `sandbox_id` is set, the `sandbox_id`/`sandbox_password`/`sandbox_signature` credentials instead. |
| `currency` | `USD` | Also read from the `iso_currency_code`/`currency_code` value or the catalog locale. |
| `pagestyle` | (unset) | PayPal-configured checkout page style. |
| `paymentaction` | `Sale` | Also `Order` or `Authorization`. |
| `headerimg`, `logoimg` | (unset) | Classic (750x90) and new-style (190x60) checkout branding images; must be served over HTTPS. |
| `cartbordercolor`, `headerbordercolor`, `headerbackcolor`, `payflowcolor` | (unset) | Checkout page colors. |
| `reqconfirmshipping` | (unset) | Require a PayPal "confirmed" address. |
| `noshipping` | (unset) | Suppress the shipping address on PayPal's pages. |
| `addressoverride` | (unset) | Show the address from the SET request instead of the one on file at PayPal. |
| `use_billing_override` | (unset) | Send the billing address instead of shipping (with `addressoverride`). |
| `localecode` | `US` | Also from the `mv_locale` session value. |
| `setordernumber` | `1` | Assigns the order number before sending the customer to PayPal, rather than after. |
| `order_counter` | `etc/order.number` | Counter file used when `setordernumber` assigns the number. |
| `notifyurl` | (unset) | IPN callback URL. |
| `itemised_basket_off` | (unset) | Suppress the itemized `PaymentDetailsItem` basket sent to PayPal. |
| `paymentdetailsitem` | (unset) | Force-include item details. |
| `buttonsource` | (unset) | Third-party BN code. |
| `soft_descriptor` | (unset) | Text on the customer's card statement. |
| `brand_name` | (unset) | Overrides the business name shown at PayPal (dropped automatically when a billing agreement is present — see Bugs in the module POD). |
| `allow_note`, `gift_message_enable`, `gift_receipt_enable`, `gift_wrap_enable`, `buyer_email_optin`, `survey_enable`, `allow_push_funding` | (unset) | Checkout feature toggles (`0`/`1`). |
| `survey_question`, `survey_choice` | (unset) | Survey text shown at PayPal. |
| `allowed_payment_method` | (unset) | `AnyFundingSource`, `InstantOnly`, or `InstantFundingSource`. |
| `landing_page`, `solution_type`, `total_type` | (unset / `EstimatedTotal`) | Checkout-flow tuning options. |
| `service_phone` | (unset) | Customer-service number shown at PayPal. |
| `seller_details` | (unset) | Appears in eBay-related emails. |
| `giropay_success_url`, `giropay_cancel_url`, `bnktxn_pending_url`, `giropay_accepted` | (unset / `1`) | Giropay bank-transfer support. |
| `gwl_enabled`, `gwl_table`, `gwl_source` | as in [GatewayLog](GatewayLog.md) | Enable/configure request-response logging for the `dorequest`/`modifyrp` call; not documented in this module's own POD. |

Sandbox and multi-account credentials, and the many recurring-billing
(`rpamount`, `rpperiod`, `rpfrequency`, ...), refund, MassPay, and virtual
terminal fields (all read from IC `[value ...]`s, not `Route`), are
detailed in the module's POD.

## Transaction types

There is no `transaction` attribute; instead, pass `pprequest` (as a tag
option, session value, or `charge_param`), default `setrequest`:

| `pprequest` | Effect |
|---|---|
| `setrequest` | Starts checkout: sends the basket total (and, by default, an itemized basket) to PayPal and stores the returned token. |
| `getrequest` | After the buyer returns from PayPal, retrieves their chosen shipping/billing address into `$::Values`. |
| `dorequest` | Captures payment for the token from `setrequest`/`getrequest`; also creates any recurring-billing profiles found in the cart. |
| `modifyrp` | Same request path as `dorequest`, for modifying an existing billing agreement. |
| `managerp_cancel`, `managerp_suspend`, `managerp_reactivate` | Cancel, suspend, or reactivate a recurring-payments profile (`rpprofileid` value required). |
| `getrpdetails` | Populates scratch space with a recurring profile's full status/schedule. |
| `billrparrears` | Bills outstanding arrears on a profile. |
| `refund`, `refund_partial` | Full or partial refund of a `transactionid`. |
| `masspay` | Pays a batch of up to 250 recipients from `[value vtmessage]`. |
| `ipn` | Validates an incoming Instant Payment Notification. |
| `getbalance`, `getbalance_<account>` | Retrieves the balance of the calling (or a named) account. |
| `dorepeat`, `sendcredit` | Additional virtual-terminal operations; see the module POD. |

## Testing

The module's own POD recommends testing against the live site (moving
funds between your personal and business PayPal accounts) over PayPal's
sandbox, which its author found unreliable; the sandbox is still reachable
via `sandbox`/`ppsandbox` and the `sandbox_*` credential options.

## Examples

Minimal Express Checkout setup, alongside another gateway as the default
route:

    Require module Vend::Payment::PaypalExpress

    Route  paypalexpress  id         xxx
    Route  paypalexpress  password   xxx
    Route  paypalexpress  signature  xxx
    Route  paypalexpress  returnurl  __SECURE_SERVER____CGI_URL__/ord/paypalgetrequest
    Route  paypalexpress  cancelurl  __SECURE_SERVER____CGI_URL__/__CHECKOUT_PAGE__

Sending the customer to PayPal from the basket page:

    [charge route="paypalexpress" pprequest="setrequest"]

Reading back their address on `pages/ord/paypalgetrequest.html`:

    [charge route="paypalexpress" pprequest="getrequest"]
    [bounce href="[area ord/paypalcheckout]"]

Capturing payment from `etc/log_transaction`:

    [charge route="paypalexpress" pprequest="dorequest" amount="[scratch tmp_remaining]" order_id="[value mv_transaction_id]"]

## See also

[Payment processing concepts](../guides/payments.md), [PayflowPro](PayflowPro.md),
[GatewayLog](GatewayLog.md), [charge](../tags/charge.md), [Route](../config/Route.md).

## Source

`lib/Vend/Payment/PaypalExpress.pm`. The module carries extensive POD
covering catalog integration and every recurring-billing/admin field; the
core configuration and `pprequest` dispatch table above were verified
against the `paypalexpress()` routine, which also reads the `gwl_*`
logging options (documented only in [GatewayLog](GatewayLog.md), not in
this module's own POD).
