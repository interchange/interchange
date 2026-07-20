# Known issues in the payment gateway modules

During the code-verified documentation pass over `lib/Vend/Payment/`
(Interchange 5.12 / git head at the time of writing), a number of defects
were found in the shipped gateway modules — places where the code does not
do what its own POD says, or does not work at all. They are collected here
so integrators can evaluate a gateway with eyes open; each module's own
[reference page](README.md) carries the detail in its Notes section.

These are long-standing issues in rarely-exercised modules and are
unlikely to be fixed; treat this page as a map of the potholes. If a
module you depend on is listed, test the specific behavior against your
gateway's sandbox before going live. When this page and a module's code
disagree, re-read the code — it may have changed since this audit.

## Crashes and wrong behavior

- **Worldpay** — calls `dbconnectwp()` in two places
  (`Worldpay.pm:532`, `:709`); no such subroutine exists anywhere in the
  codebase, so those code paths die at runtime. The module cannot be used
  as shipped without supplying that routine.
- **Getitcard** — the transaction map sends `void` as the gateway's
  `commit` operation (its POD documents the opposite pairing), and there
  is no `settle` mapping at all — a `settle` request goes out effectively
  empty. On a response-checksum mismatch, the customer-facing error is set
  from an undefined variable and comes out blank. The shared-secret option
  is `secret`, not the POD's `secure`.
- **Ezic** — the credit/void follow-on branch tests a variable that is
  never assigned, so it is unreachable; `site_id` is read from
  configuration but never sent (only `site_tag` is); and no MD5 hash is
  included in requests despite `Digest::MD5` being listed as a
  prerequisite.
- **TestPayment** — the `return` transaction branch has inverted logic
  relative to `settle`/`void`: it *fails* when `auth_code` is supplied and
  succeeds when it is absent. Harmless (test module), but confusing when
  exercising checkout flows.
- **Protx2** — the hard-coded default host is the *test* server
  (`ukvpstest.protx.com`). A catalog that never sets `host` silently
  transacts against the sandbox. Always set `host` explicitly.
- **Sage** — the `precision` option is read into the option hash, but the
  rounding code references a different, never-assigned variable (the
  module lacks `use strict`), so the option has no effect.

## Options that are accepted but do nothing

- **Cardsave** — the CV2-override policy check tests a misspelled key
  (`cv2ovreridepolicy`), so setting `cv2overridepolicy` can never suppress
  that decline; the POD's `address_error`/`postcode_error`/`cv2_error`
  Route options are never read (messages are hard-coded).
- **PSiGate** — the documented `test` option (`x_Test_Request`) is
  unimplemented; the `referer` read is commented out, so the `Referer`
  header is always blank.
- **BusinessOnlinePayment** — `message_avs` sits behind an `if (0)` block;
  declines always use `message_declined`.
- **PayflowPro** — `addressoverride` and `use_billing_override` are
  documented but never read in the current routine.
- **SagePay** — `check_status` and `checkouturl` are read but have no
  effect. **TCLink** — `referer` is read and never used. **HSBC** —
  `bypass3ds` and `finalcheckoutpage` are read but not visibly acted on.

## Documentation drift (POD promises the code does not keep)

- **Braintree** — the POD's transaction table lists a `return` type; the
  code's type map has no such key, so `transaction=return` is rejected.
- **EFSNet** — POD maps `reverse` to `CreditCardRefund`; the code has no
  `reverse` mapping (the literal word is passed through and rejected).
  The POD's `Variable MV_PAYMENT_HOST` test-host claim is wrong — only a
  `Route ... host` setting is honored.
- **MCVE** — `void`/`return`/`delete` are mapped to gateway operations
  that have no implementation in the module (its POD says "not supported
  yet"; the mappings make them look supported).
- **PRI** — the POD's `variable.txt` example (`PRI_REGKEY`,
  `PRI_TEST_ID`, ...) is misleading: only `id` and `precision` fall back
  to `MV_PAYMENT_*` Variables; everything else must be set as Route or
  call options.
- **Merchantware** — a plain `void` always resolves to
  `VoidPreAuthorization` in practice (the discriminating condition is
  always true), which no documentation mentions.

## See also

- [Payment gateway index](README.md) — per-module pages with the detailed
  Notes these entries summarize
- [Payment processing guide](../guides/payments.md) — the charge model,
  and [TestPayment](TestPayment.md) for offline testing
