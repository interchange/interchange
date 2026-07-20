# Payment modules

Each page below documents one `Vend::Payment::*` module — the gateway or
processor it talks to, the transaction types it supports, and how to configure
it. You select a module with the `Route` and `gateway` settings described in
the [payments](../guides/payments.md) guide, then invoke it with the
[charge](../tags/charge.md) tag.

Two entries are not gateways of their own: [GatewayLog](GatewayLog.md) is a
shared logging base class that several drivers inherit to record each
transaction attempt to a database table, and [TestPayment](TestPayment.md) is
an offline, no-network module that approves or declines by inspecting the card
number, so you can test checkout end to end without a real account.

> **Documented code bugs.** Several modules have bugs that survive in the
> current source — off-by-one field handling, response-parsing quirks, and
> similar. Where one exists it is called out in that page's **Notes** section;
> read it before you deploy the module.

## Modules

- [AuthorizeNet](AuthorizeNet.md) — Authorize.Net gateway via its v3 "AIM"
  API, for card and eCheck charges, credits, and voids.
- [Braintree](Braintree.md) — Braintree (a PayPal company) via
  `Net::Braintree`, with vaulted-customer and client-token flows.
- [BusinessOnlinePayment](BusinessOnlinePayment.md) — generic wrapper over the
  CPAN `Business::OnlinePayment` framework, for gateways with no native driver.
- [Cardsave](Cardsave.md) — Cardsave (UK) via its SOAP/XML API, with full 3-D
  Secure and token-based repeat/refund/void.
- [CyberSource](CyberSource.md) — CyberSource via its SOAP Simple Order API;
  supersedes [ICS](ICS.md) and adds Bill Me Later, PayPal, and eCheck.
- [EFSNet](EFSNet.md) — Concord EFSNet via name/value-pair HTTPS POST, modeled
  on [AuthorizeNet](AuthorizeNet.md).
- [Ezic](Ezic.md) — EziC "Native Direct Mode v3 (SAS)" HTTPS channel for card
  charges.
- [GatewayLog](GatewayLog.md) — not a gateway; a shared base class that logs
  every transaction attempt to a database table for the drivers that use it.
- [Getitcard](Getitcard.md) — Getitcard prepaid cards with a separate
  authorize/commit/cancel flow.
- [HSBC](HSBC.md) — HSBC/GlobalIris ePayments, with 3-D Secure and configurable
  fraud screening.
- [ICS](ICS.md) — CyberSource's legacy ICS2 Perl SDK; the older CyberSource
  integration (see [CyberSource](CyberSource.md) for the current one).
- [iTransact](iTransact.md) — iTransact's hosted order form, redirecting the
  result back to Interchange; single sale transaction.
- [Linkpoint](Linkpoint.md) — LinkPoint Secure Payment Gateway via the
  `lpperl`/`curl` client; authorize, sale, and capture.
- [MCVE](MCVE.md) — MCVE/Mainstreet Credit Verification Engine daemon via its
  Perl client; authorize and sale.
- [Merchantware](Merchantware.md) — Merchant Warehouse's Merchantware SOAP API;
  sale, auth/capture, refund, void, token repeat, and Level 2.
- [NetBilling](NetBilling.md) — NetBilling Direct Mode 2.1 for card or ACH,
  with AVS, authorize, sale, capture, credit, and refund/void.
- [PayflowPro](PayflowPro.md) — PayPal Payflow Pro HTTPS POST; also drives
  PayPal Express Checkout when an `action` is given.
- [PaypalExpress](PaypalExpress.md) — PayPal Express Checkout via the classic
  SOAP API, with recurring billing, refund, MassPay, and IPN.
- [PRI](PRI.md) — Payment Resources International via its `processCC.asp` API;
  `sale` only.
- [Protx2](Protx2.md) — Protx (later Sage Pay) "Direct" system, keeping the
  customer on-site; payment, deferred, and virtual-terminal types.
- [PSiGate](PSiGate.md) — PSiGate "HTML Posting Direct Response" API; sale,
  pre-auth, post-auth, and void.
- [Sage](Sage.md) — Sage Payment Solutions (formerly Vital) `eftBankcard.dll`
  API; sale, auth, capture, void, and credit.
- [SagePay](SagePay.md) — Sage Pay (renamed Protx, see [Protx2](Protx2.md))
  "Direct" system, with 3-D Secure and virtual-terminal operations.
- [TCLink](TCLink.md) — TrustCommerce TCLink via CPAN `Net::TCLink`;
  pre-auth, sale, post-auth, and credit.
- [TestPayment](TestPayment.md) — offline test module; approves or declines by
  card number, no network or account needed.
- [Worldpay](Worldpay.md) — Worldpay hosted "Select Junior"/WCC page, driving a
  two-stage redirect-and-callback flow into the order tables.
