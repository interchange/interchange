# Getitcard (Vend::Payment::Getitcard)

Charges prepaid cards issued by Getitcard (getitcard.com) using its HTTPS
API, with a separate authorize/commit/cancel flow (an "authorize" step, an
optional later "commit" to actually capture funds, and a "cancel" to
release an authorization).

## Prerequisites

- `Digest::SHA` (used to compute the request's SHA-256 `enckey`
  authentication field).
- `Net::SSLeay`, or `LWP::UserAgent` with `Crypt::SSLeay`.
- A Getitcard merchant account number and MD5/SHA secret key.

## Configuration

    Require module Vend::Payment::Getitcard        # interchange.cfg
    Variable MV_PAYMENT_MODE getitcard              # catalog.cfg
    Route  getitcard  id       YourGetitcardID
    Route  getitcard  secret   YourGetitcardSecret
    Route  getitcard  currency EUR

`id`, `currency`, and `secret` are all required — the module returns a hard
"Configuration error" failure if any is missing.

| Option        | Default                  | Meaning |
|---------------|---------------------------|---------|
| `id`          | none (required)           | Getitcard merchant/store number, sent as `account_id`. |
| `currency`    | none (required)           | Currency code sent with the request. |
| `secret`      | none (required)           | Shared secret used to compute the SHA-256 `enckey` on requests and to verify the response `checksum`. |
| `host`        | `secure.getitcard.com`    | Getitcard API host. |
| `transaction` | `sale`                    | Requested transaction; see [Transaction types](#transaction-types) and the contradiction noted below. |
| `order_id`    | none (required for follow-on calls) | Getitcard's own transaction number ("transact"), received as the result of an `authorize` call; required for `commit`/`cancel` follow-ups. |
| `order_number`| generated order id if unset | Interchange's own order identifier, sent with every request. |
| `precision`   | `2`                       | Decimal places for the amount. Values greater than `2` are rejected outright. |

> **POD/code contradiction — option name:** the POD documents an option
> called `secure` ("MD5 checksum required for valid transactions") as one of
> the "active settings". The code never reads `secure` anywhere; the actual
> option it reads is `secret` (`$opt->{secret}`, `charge_param('secret')`).
> Use `Route getitcard secret ...`, not `secure`.

## Transaction types

The code's actual mapping (`%type_map` in the module):

| Interchange              | Getitcard action |
|----------------------------|---------------------|
| `sale` (default)            | `authorize` with `commit=YES` in the same call |
| `auth`, `authorize`         | `authorize` (`commit=NO`) |
| `void`                      | `commit` |
| `return`                    | `cancel` |

You can also pass Getitcard's own action names directly (`authorize`,
`commit`, `cancel`), since any transaction value not found in `%type_map` is
used as-is; the module's own POD's examples do exactly this.

> **POD/code contradiction — transaction mapping:** the module's "active
> settings" section documents `settle` → `commit` and `void` → `cancel`. The
> code's `%type_map` instead has **no `settle` entry at all**, and maps
> **`void` → `commit`** (not `cancel`). Concretely:
> - `transaction=void`, used as the POD's own table suggests to cancel/void
>   a transaction, actually triggers a **commit** (capturing funds) rather
>   than a cancellation.
> - `transaction=settle` is not recognized by any branch in the code (it
>   does not match the `authorize|sale` regex nor the literal `commit`/
>   `cancel` checks), so the request is built with an **empty query hash**
>   and nothing meaningful is sent to Getitcard.
>
> To reliably commit or cancel, pass Getitcard's own action names directly:
> `transaction=commit` (capture a prior authorization) or
> `transaction=cancel` (release it), as shown in the module's own
> `EXAMPLES` section, rather than the `settle`/`void` names implied by its
> "active settings" table.

> **Bug found in the module:** on a checksum-verification failure (the
> response's SHA-256 `checksum` doesn't match what the module computes), the
> code sets `MErrMsg => $call_error_msg` — a variable that is never defined
> anywhere in the file (the defined variable is `$conf_error_msg`). Because
> the module has no `use strict`, this silently evaluates to an empty
> string rather than raising a compile error, so the customer-facing error
> message is blank in that specific failure case (the `pop.error-message`
> field is still set correctly to "Data doesn't match the checksum.").

## Testing

The module has no separate `test`/sandbox flag; use whatever test
credentials and card numbers Getitcard issues for its own test environment,
pointed at the same `host`.

## Examples

Minimal `catalog.cfg` fragment:

    Variable MV_PAYMENT_MODE getitcard
    Route  getitcard  id       YourGetitcardID
    Route  getitcard  secret   YourGetitcardSecret
    Route  getitcard  currency EUR

Sale (authorize and capture together):

    [charge gateway="getitcard" amount="12"]

Authorize only, then commit later using the returned Getitcard transaction
number:

    [charge gateway="getitcard" transaction="authorize" amount="123"]
    ...
    [charge gateway="getitcard" transaction="commit" order_id="12345" order_number="123456"]

Cancel a prior authorization:

    [charge gateway="getitcard" transaction="cancel" order_id="12345" order_number="123456"]

## See also

[Payment processing concepts](../guides/payments.md).

## Source

`lib/Vend/Payment/Getitcard.pm` (has its own POD; the transaction-type
mapping and the `secure`/`secret` option name in that POD do not match the
current code — see caveats above).
