# Sage Pay Direct (Vend::Payment::SagePay)

Processes card payments through Sage Pay's ("SagePay", the renamed
successor to Protx -- see [Protx2](Protx2.md)) "Direct" system, including
3-D Secure authentication, deferred/release settlement, and
virtual-terminal operations (refund, repeat, void, and similar).

## Prerequisites

One of:

- `Net::SSLeay`
- `LWP::UserAgent`, `Crypt::SSLeay`, `CGI`, and `Encode`

A recent `wget` built with SSL and `--connect-timeout` support, only
needed if you enable the `available` gateway-reachability check.

3-D Secure also requires three pages in your catalog (`ord/tdsfinal`,
`ord/tdsauth`, `ord/tdsreturn`) and an edit to `etc/log_transaction`, all
documented in the module's own POD.

## Configuration

    Require module Vend::Payment::SagePay        # interchange.cfg
    Variable MV_PAYMENT_MODE  sagepay             # catalog.cfg
    Route  sagepay  id       YourSagePayID
    Route  sagepay  host     test.sagepay.com     # or live.sagepay.com
    Route  sagepay  currency GBP

The module defines a `sagepay` routine (lowercase), so the gateway/mode
name must be `sagepay`.

| Option | Default | Meaning |
| --- | --- | --- |
| `id` | none | Your Sage Pay vendor ID. Also settable as `MV_PAYMENT_ID`. |
| `host` | `live.sagepay.com` | Sage Pay server to post to. Also settable as `MV_PAYMENT_HOST`. |
| `txtype` | `PAYMENT` | One of `PAYMENT`, `AUTHENTICATE`, `DEFERRED` for a purchase, or `AUTHORISE`, `REFUND`, `RELEASE`, `REPEAT`, `DIRECTREFUND`, `VOID`, `ABORT`, `CANCEL`, `MANUAL` for virtual-terminal operations. Read first from the page value `transtype`, then this Route option, then `MV_PAYMENT_TRANSACTION`. |
| `account_type` | `E` | Sage Pay `AccountType` field. Overridable from the page as `account_type`. |
| `currency` | `GBP` | ISO currency code. Checked in order: page/product `iso_currency_code`, the catalog locale's `iso_currency_code`, this Route option, `MV_PAYMENT_CURRENCY`, then the hard-coded default. |
| `applyavscv2` | `0` | Sage Pay `ApplyAVSCV2`: `0` check if enabled and apply rules, `1` force checks, `2` force no checks, `3` force checks without rules. Overridable from the page as `applyavscv2`; forced to `2` for anything other than `PAYMENT`/`DEFERRED`/`AUTHORISE`. |
| `apply3ds` | `0` | Sage Pay `Apply3DSecure`. Overridable from the page as `apply3ds`; forced to `2` (off) for anything other than `PAYMENT`/`DEFERRED`/`AUTHENTICATE`. |
| `giftaidpayment` | `0` | Set to `1` to mark the payment as a Gift Aid donation. Overridable from the page as `giftaidpayment`. |
| `available` | `no` | If `yes`, probe the gateway with `wget` before sending; on failure the order is logged as `OFFLINE` for later manual processing. Maestro/Switch cards always go through even when the probe fails, since they must use 3-D Secure. |
| `logzero` | `no` | If `yes`, log a zero-amount transaction instead of skipping the gateway call. |
| `logorder` | `no` | If `yes`, also write the full basket via the `logorder` custom UserTag (not shipped; you must supply it) as an audit backup. |
| `logsagepay` | `no` | If `yes`, append a plain-text record of the transaction to `logs/sagepay.log`. |
| `returnurl` | `SECURE_SERVER` + `CGI_URL` + `/ord/tdsreturn` | 3-D Secure `TermUrl`, where the card issuer's ACS redirects the customer back. |
| `use_wget` | `1` | Passed through to the HTTP layer. |
| `allowmaestro` | unset | If true, a Maestro/Switch card is allowed through even when the availability probe reports the gateway down. |

## Transaction types

| `txtype` | Meaning |
| --- | --- |
| `PAYMENT` | Takes funds immediately. May later be `REFUND`ed or `REPEAT`ed. |
| `AUTHENTICATE` | Validates the card without moving funds; follow with `AUTHORISE` to settle. |
| `DEFERRED` | Places a shadow hold for about seven days; follow with `RELEASE` to settle. |
| `RELEASE` | Settles a prior `DEFERRED`. |
| `REFUND` | Refunds a `PAYMENT`, `RELEASE`, or `REPEAT`, in full or in part. |
| `DIRECTREFUND` | Sends funds to a card without referencing a prior transaction. |
| `REPEAT` | Re-runs a prior `AUTHORISE` or `PAYMENT` for a new amount. |
| `VOID`, `ABORT`, `CANCEL` | Cancel an unsettled transaction. |
| `MANUAL` | Manually keyed transaction. |

When Sage Pay reports `Status=3DAUTH`, the module stores the ACS URL and
`PaReq`/`MD` values in `$Scratch` and issues an HTTP redirect to
`ord/tdsfinal`, which is expected to run the bank's authentication page
in an iframe and return through `ord/tdsreturn`
(`[charge route="sagepay" sagepayrequest="3dsreturn"]`) to complete the
transaction -- the module runs in two passes for a 3-D Secure order.

## Testing

Set `host` to `test.sagepay.com`. Only the card numbers documented in
the module's POD authorize successfully on the test server, along with
CV2 `123`, address number `88`, postcode number `412`, and the test
server's fixed password `password`. The test site's `SecureStatus`
response is liable to read `NOTAUTHED` where the live site would return
`OK`, so 3-D Secure results are not directly comparable between test and
live.

## Examples

Minimal live route:

    Variable MV_PAYMENT_MODE  sagepay
    Route  sagepay  id        YourSagePayID
    Route  sagepay  host      live.sagepay.com
    Route  sagepay  currency  GBP

    [charge route="sagepay"]

Deferred authorization for later release:

    Route  sagepay  txtype  DEFERRED

    [charge route="sagepay" transtype="DEFERRED"]

## Notes

Two Route options are read but never actually change behavior in the
current code: `check_status` (`charge_param('check_status')`) is
assigned to a variable that is only ever printed in a debug log line,
and `checkouturl` (`charge_param('checkouturl')`) is assigned but never
referenced again afterward.

## See also

[Protx2](Protx2.md), [Payment processing concepts](../guides/payments.md).

## Source

`lib/Vend/Payment/SagePay.pm`, subroutine `sagepay` in package
`Vend::Payment` (has its own POD).
