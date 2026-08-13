# ICS (Vend::Payment::ICS)

Charges cards through CyberSource's legacy Interactive Content Services
(ICS2) Perl SDK. This is the older CyberSource integration, driven by
CyberSource's own `ICS.pm` client library and its "application" model
(`ics_auth`, `ics_bill`, `ics_dav`, and so on). It is not the same
integration as [CyberSource](CyberSource.md), which talks to CyberSource's
newer SOAP Simple Order API directly and does not require the CyberSource
SDK.

## Prerequisites

CyberSource's ICS Perl SDK (its own `ICS.pm`, separate from this module's
`Vend::Payment::ICS`), installed with the "keys" directory CyberSource
issues for your merchant account. A CyberSource merchant account configured
for ICS2.

## Configuration

    Require module Vend::Payment::ICS                    # interchange.cfg

    Variable  MV_PAYMENT_MODE  ICS                        # catalog.cfg
    Route  ICS  server_host  ics2test.ic3.com
    Route  ICS  server_port  80
    Route  ICS  path         /path/to/lib/CyberSource/SDK
    Route  ICS  merchant_id  your_merchant_id
    Route  ICS  apps         ics_auth,ics_auth_reversal,ics_bill,ics_credit
    Route  ICS  timeout      20
    Route  ICS  merchant_descriptor          "test merchant"
    Route  ICS  merchant_descriptor_contact  "phone number"

| Option | Default | Meaning |
|---|---|---|
| `server_host` | (required) | CyberSource ICS server, e.g. `ics2test.ic3.com` for testing or `ics2.ic3.com` for production. |
| `server_port` | (required) | Port to connect to on `server_host`. |
| `path` | (required) | Filesystem path to the CyberSource SDK, containing the merchant `keys` directory. Set as the `ICSPATH` environment variable before calling `ics_send`. |
| `merchant_id` | (required) | Your CyberSource merchant ID. |
| `apps` | (required) | Comma- or space-separated list of ICS "applications" to run, e.g. `ics_dav,ics_export,ics_score,ics_auth,ics_bill`. Only the applications relevant to the current transaction type are actually sent (see below). |
| `timeout` | `10` | Seconds to wait for the CyberSource response. |
| `currency` | `usd` | Falls back to the catalog locale's `currency_code` if unset. |
| `merchant_descriptor` | (optional) | Text shown on the customer's card statement; used by `ics_auth`, `ics_bill`, and `ics_credit`. |
| `merchant_descriptor_contact` | (optional) | Merchant contact info paired with `merchant_descriptor`. |
| `ignore_avs` | `yes` | Passed straight to CyberSource as part of the `ics_auth` request. |
| `ignore_bad_cv` | `yes` | Passed straight to CyberSource as part of the `ics_auth` request. |

Address, card, and customer fields (`bill_address1`, `bill_city`,
`customer_cc_number`, `customer_email`, and so on) are populated
automatically from the order's standard values (billing and shipping
address, card fields) and do not normally need to be set as options.
Billing/shipping address fields are exempted from the required-field check
when the country is `us` or `ca`.

## Transaction types

Set with the `transaction` option (`cyber_mode` is accepted as an alias),
default `auth`:

| Interchange | ICS application chain | CyberSource op |
|---|---|---|
| `auth`, `authorize`, `mauthonly`, `mauthdelay`, `A` | `ics_dav`, `ics_export`, `ics_score`, `ics_auth` | Authorize only. |
| `sale`, `mauthcapture`, `S` | adds `ics_bill` to the auth chain | Authorize and capture. |
| `void`, `V` | `ics_auth_reversal` | Reverse a prior authorization (`auth_request_id` required). |
| `settle`, `D` | `ics_bill` | Capture a prior authorization (`auth_request_id` required). |
| `credit`, `mauthreturn`, `C` | `ics_credit` | Refund. |

Each application chain has its own required-field list; if a needed field
is missing, `ICS()` returns `MStatus => 'failure-hard'` with a "Missing
value for >field<" message before any request is sent to CyberSource.

## Testing

Point `server_host` at CyberSource's test server (`ics2test.ic3.com`) with
a test merchant ID; there is no separate test-mode flag in the module.

## Examples

Minimal auth-and-capture setup:

    Require module Vend::Payment::ICS

    Variable  MV_PAYMENT_MODE  ICS
    Route  ICS  server_host  ics2test.ic3.com
    Route  ICS  server_port  80
    Route  ICS  path         /usr/local/cybersource/keys
    Route  ICS  merchant_id  test_merchant
    Route  ICS  apps         ics_dav,ics_export,ics_score,ics_auth,ics_bill

Charging the order total as a sale:

    [charge route="ICS" transaction="sale"]

## See also

[Payment processing concepts](../guides/payments.md), [CyberSource](CyberSource.md),
[charge](../tags/charge.md), [Route](../config/Route.md).

## Source

`lib/Vend/Payment/ICS.pm`. The module's own POD is a short quick-start;
the option, requirement, and transaction-mapping tables above were built
directly from the `ICS()` routine's `%required_map`, `%optional_map`,
`%default_map`, and `%type_map`.
