# CreditCardAuto

Enables automatic encryption of credit card information submitted with an
order. Reach for it when you collect card data and want Interchange to
encrypt it as it comes in, using your configured encryption program.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    CreditCardAuto  yes|no

A boolean (`parse_yesno`): `Yes`, `No`, `1`, `0`, and so on,
case-insensitive. Default: `No`.

## Description

When enabled, Interchange automatically gathers the credit card fields
from the submitted form, encrypts them with the catalog's
[EncryptProgram](EncryptProgram.md), and stores the encrypted result
(rather than the raw card number) for the order. This spares you from
wiring up encryption by hand in each order profile.

[EncryptProgram](EncryptProgram.md) must be configured and working before
`CreditCardAuto` has any useful effect; without a working encryptor there
is nothing to encrypt the captured data with.

## Examples

Turn on automatic card encryption:

```
CreditCardAuto Yes
```

Paired with a GPG-based encryptor:

```
EncryptProgram  /usr/bin/gpg --batch --always-trust -e -r orders@example.com
CreditCardAuto  Yes
```

## Notes

This directive is about encrypting captured card data in transit through
Interchange; it is not a substitute for a payment gateway or for PCI-DSS
compliance. Store as little card data as your payment flow allows.

## See also

[EncryptProgram](EncryptProgram.md), [PGP](PGP.md),
[EncryptKey](EncryptKey.md), the
[payments](../guides/payments.md) and [security](../guides/security.md)
guides.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{CreditCardAuto}` during request dispatch in
`lib/Vend/Dispatch.pm` (which calls `Vend::Order::encrypt_standard_cc` on
the submitted `mv_credit_card_number`).
