# Protx Direct (Vend::Payment::Protx2)

Processes card payments through the Protx (later renamed Sage Pay,
documented separately as [SagePay](SagePay.md)) "Direct" system, the only
Protx product that keeps the customer on your site while charging the
card in real time. It supports payment, deferred, and virtual-terminal
transaction types, plus optional 3-Securely-adjacent gateway-availability
checking.

## Prerequisites

One of:

- `Net::SSLeay`
- `LWP::UserAgent` and `Crypt::SSLeay`

A recent `wget` built with SSL and `--connect-timeout` support, only
needed if you enable the `available` gateway-reachability check.

## Configuration

    Require module Vend::Payment::Protx2         # interchange.cfg
    Variable MV_PAYMENT_MODE  protx               # catalog.cfg
    Route  protx  id        YourProtxID
    Route  protx  host      ukvpstest.protx.com   # or ukvps.protx.com for live
    Route  protx  currency  GBP

The module defines a `protx` routine, so the gateway/mode name must be
`protx` (set `Route mode gateway protx` if you name the mode something
else).

| Option | Default | Meaning |
| --- | --- | --- |
| `id` | none | Your Protx vendor ID. Also settable as `MV_PAYMENT_ID`. |
| `host` | `ukvpstest.protx.com` | Protx server to post to. **The hard-coded default is the test server, not live** -- set this explicitly for a production route. Also settable as `MV_PAYMENT_HOST`. |
| `txtype` | `PAYMENT` | One of `PAYMENT`, `AUTHENTICATE`, `DEFERRED` for a purchase, or `AUTHORISE`, `RELEASE`, `REFUND`, `REPEAT`, `DIRECTREFUND`, `VOID`, `ABORT`, `CANCEL`, `MANUAL` for virtual-terminal operations. Read first from the page value `transtype`, then this Route option, then `MV_PAYMENT_TRANSACTION`. |
| `account_type` | `E` | Protx `AccountType` field. Also overridable from the page as `account_type`. |
| `currency` | `GBP` | ISO currency code. Checked in order: page/product `iso_currency_code`, the catalog locale's `iso_currency_code`, this Route option, `MV_PAYMENT_CURRENCY`, then the hard-coded default. |
| `applyavscv2` | `0` | Protx `ApplyAVSCV2`: `0` check if enabled and apply rules, `1` force checks, `2` force no checks, `3` force checks without rules. Overridable from the page as `applyavscv2`. Forced to `2` for `REPEAT`/`RELEASE`/`REFUND`. |
| `giftaidpayment` | `0` | Set to `1` to mark the payment as a Gift Aid donation. Overridable from the page as `giftaidpayment`. |
| `available` | `no` | If `yes`, probe the gateway with `wget` before sending; on failure (or timeout) the order is logged as `OFFLINE` for later manual processing instead of failing outright. |
| `logzero` | `no` | If `yes`, log a zero-amount transaction (useful for a mid-subscription audit entry) instead of skipping the gateway call. |
| `logempty` | `no` | If `yes`, an empty gateway response is forced to `success` (flagged for manual verification) instead of left as a failure. |
| `double_pay` | `no` | If `yes`, reject a repeat charge for the same order when a marker file from a prior successful payment already exists (checked only when the order route matches `ptipm_route` or `protx_vt_route`). |
| `logdir` | system `/tmp` | Directory for the double-payment marker files. Must resolve under `Vend::File::allowed_file`, or the default is used instead. |
| `logdir_from_user_allowed` | unset | Must be `1` before a page-supplied `logdir` form value is honored; otherwise a user-supplied `logdir` is rejected and logged. |
| `use_wget` | `1` | Passed through to the HTTP layer. |

## Transaction types

| `txtype` | Meaning |
| --- | --- |
| `PAYMENT` | Takes funds immediately. May later be `REFUND`ed or `REPEAT`ed. |
| `AUTHENTICATE` | Validates the card and holds the details at Protx for up to 90 days; follow with `AUTHORISE` for up to 115% of the original value. |
| `DEFERRED` | Places a shadow hold for about seven days; follow with `RELEASE` to settle. |
| `RELEASE` | Settles a prior `DEFERRED`. |
| `REFUND` | Refunds a `PAYMENT`, `RELEASE`, `AUTHORISE`, or `REPEAT`, in full or in part. |
| `DIRECTREFUND` | Sends funds to a card without referencing a prior transaction. |
| `REPEAT` | Re-runs a prior `AUTHORISE` or `PAYMENT` for a new amount. |
| `VOID`, `ABORT`, `CANCEL` | Cancel an unsettled transaction. |
| `MANUAL` | Manually keyed transaction. |

Card type is auto-detected from the number by regex unless the page
supplies `mv_credit_card_type` directly (recommended, since a regex
change on Protx's side would otherwise cause silent misdetection).
Maestro (and Switch) cards are always rejected by this module ("we do
not accept Maestro cards") because Protx requires 3-D Secure for them,
which this Direct-only module does not implement.

## Testing

Point `host` at `ukvpstest.protx.com` (the module's own default). Only
the card numbers documented in the module's POD authorize successfully
on the test server, and only the CV2 value `123`, address number `88`,
and postcode number `412` return matched AVS/CV2 results; any other
values report as not matched.

## Examples

Minimal live route:

    Variable MV_PAYMENT_MODE  protx
    Route  protx  id        YourProtxID
    Route  protx  host      ukvps.protx.com
    Route  protx  currency  GBP

    [charge route="protx"]

Deferred authorization for later release:

    Route  protx  txtype  DEFERRED

    [charge route="protx" transtype="DEFERRED"]

## Notes

`find_card_type` is read from the Route (`charge_param('find_card_type')`)
but the value is never consulted afterward; the module always attempts
its own regex-based detection whenever the page does not supply
`mv_credit_card_type`, regardless of this setting.

## See also

[SagePay](SagePay.md), [Payment processing concepts](../guides/payments.md).

## Source

`lib/Vend/Payment/Protx2.pm`, subroutine `protx` in package
`Vend::Payment` (has its own POD).
