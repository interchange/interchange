# Ezic (Vend::Payment::Ezic)

Charges credit cards through EziC's "Native Direct Mode v3 (SAS)" HTTPS
channel (`secure.ezic.com`), modeled on the same request/response style as
[AuthorizeNet](AuthorizeNet.md).

> **Significant code-quality caveat:** this module has bugs that mean parts
> of its documented behavior do not work as described. They are detailed
> below rather than silently reproduced, per the project's code-is-authority
> rule. If you are integrating with EziC today, read this section carefully
> and test thoroughly before relying on this driver in production.

## Prerequisites

- `URI::Escape`
- `Net::SSLeay`, or `LWP::UserAgent` with `Crypt::SSLeay`
- `Digest::MD5` (required at load time, but see note below — it is never
  actually called anywhere in the module)
- An EziC merchant account (12-digit account number, configured in the EziC
  control panel).

## Configuration

    Require module Vend::Payment::Ezic            # interchange.cfg
    Variable MV_PAYMENT_MODE ezic                  # catalog.cfg
    Route  ezic  account_id  YourAccountNumber
    Route  ezic  site_tag    YourSiteTag

Unlike this module's own POD (which says the account number is set with
`id`, e.g. `Route ezic id ...` or `Variable MV_PAYMENT_ID`), **the code
never reads that value**. The query field actually sent to EziC as
`account_id` is taken only from an `account_id` option/route key
(`$opt->{account_id}`), read directly — not through `charge_param()`, and
not from `id`. The `charge_param('id')` call in the code populates a
variable (`$user`) that is never used elsewhere.

| Option        | Default | Meaning |
|---------------|---------|---------|
| `account_id`  | none    | EziC account number, sent as the `account_id` field. This is the option that actually works — despite the POD documenting `id`/`MV_PAYMENT_ID` for this purpose. Read directly from `$opt`, not `charge_param()`. |
| `site_tag`    | none    | Sent as the `site_tag` field. The POD instead documents a `site_id` option, which the code does read into a variable but **never places into the outgoing request** — it has no effect. Use `site_tag` if your EziC site configuration requires it. |
| `transaction` | `auth`  | Requested transaction; see [Transaction types](#transaction-types) and the important caveat below. |
| `master_id`   | none    | Intended to reference a prior transaction (EziC `orig_id`) for refund/void follow-on calls. Not documented in the POD. See caveat below — the code path that would use this is currently unreachable. |
| `referer`     | none    | HTTP `Referer` header sent with the request (`charge_param('referer')`, so also settable via `Variable MV_PAYMENT_REFERER`). |
| `precision`   | `2`     | Decimal places used when computing the amount from the cart total. |
| `message_avs` | built-in English text | Error message template used when the AVS check fails. |
| `message_cvv2`| built-in English text | Error message template appended when the CVV2 check fails. |
| `message_declined` | built-in English text | Message used for any decline; **note this is set unconditionally at the end of the failure branch**, overwriting whatever `message_avs`/`message_cvv2` text was already built into `MErrMsg` — in practice only the `message_declined` text ever reaches the customer. |

`host` (`secure.ezic.com`), `script` (`/gw/sas/direct3.0`), and `port`
(`1402`) can be overridden via a `Route`/option of the same name, read
directly (not through `charge_param()`).

> **Code bugs found (not POD/code mismatches, but bugs in the module
> itself):**
> - Ezic.pm does not have `use strict` in its `Vend::Payment` package (its
>   sibling modules like AuthorizeNet.pm and EFSNet.pm do). This let several
>   real bugs through undetected:
>   - The branch that is supposed to send a lightweight follow-on request
>     (`account_id`, `tran_type`, `orig_id`) for credit/void transactions
>     tests `$transaction !~ m/(R|C)/i` — but `$transaction` is never
>     assigned anywhere; only `$transtype` (the mapped EziC transaction
>     letter) is. Because `$transaction` is always `undef`, this condition
>     is always true, so **every transaction, including credits and voids,
>     goes through the full-card-details branch**; the `master_id`/`orig_id`
>     follow-on path is unreachable as written.
>   - No authentication secret, password, or hash value is ever included in
>     the outgoing request (`$secret` and `$hash` are read but never placed
>     in the `%query` hash), even though `Digest::MD5` is a stated
>     prerequisite. Whether your EziC account requires such a value depends
>     on your account configuration; if it does, this module as written
>     cannot supply it.
> - Given the above, treat this module as needing repair/verification
>   against a live EziC test account before production use.

## Transaction types

| Interchange                | EziC code |
|------------------------------|-------------|
| `sale`, `mauthcapture`        | `S` (Sale) |
| `auth`, `authorize`, `mauthonly` (default) | `A` (Auth) |
| `settle`, `settle_prior`     | `D` (Capture) |
| `return`                     | `C` (Credit) |
| `reverse`, `void`            | `R` (Refund) |

Both `reverse` and `void` map to EziC's `R` (Refund) code — there is no
separate true "void" transaction type in this module.

## Testing

Enable test mode from within the EziC control panel itself (there is no
module-level `test` option); a test order should then complete using the
test card number configured in the control panel's "setup" section.

## Examples

Minimal `catalog.cfg` fragment (using the option that actually works):

    Variable MV_PAYMENT_MODE ezic
    Route  ezic  account_id  YourAccountNumber
    Route  ezic  site_tag    YourSiteTag

Charging the current order total:

    [charge mode="ezic" interaction="charge"]

## See also

[Payment processing concepts](../guides/payments.md), [AuthorizeNet](AuthorizeNet.md).

## Source

`lib/Vend/Payment/Ezic.pm` (has its own POD; several documented behaviors do
not match the current code — see caveats above).
