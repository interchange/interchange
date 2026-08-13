# EncryptKey

Specifies the default key (or key holder identity) used when Interchange
encrypts data such as credit card numbers. Reach for it to name the GnuPG/PGP
recipient that protected data should be encrypted to.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    EncryptKey  key_or_user_identifier

The raw value is stored as a string (no parser is run). Give a GnuPG/PGP key
identifier (for example a key ID) or any part of a user identity (such as an
email address) that your keyring resolves to a single key. Multiple keys may be
listed separated by spaces or commas. Default: empty.

## Description

When Interchange encrypts data through its PGP/GnuPG path (`pgp_encrypt` in
`lib/Vend/Order.pm`), the recipient key defaults to `EncryptKey` unless a key is
passed explicitly. The key text is normalized (commas become spaces, surplus
whitespace collapsed) and each key is passed to the encryption program as a
recipient. `EncryptKey` also gates card encryption in the payment path: card
numbers are only encrypted when a key is configured (`lib/Vend/Payment.pm`).

GnuPG accepts either a key identifier or part of a user identity, so both forms
work.

## Examples

Encrypt to a key by its ID, in `catalog.cfg`:

```
EncryptKey 9B726B71
```

Encrypt to a key selected by email address:

```
EncryptKey orders@example.com
```

The shipped strap `catalog.cfg` sets this from an install-time token:

```
EncryptKey  __PGP_KEY__
```

## Notes

Encryption also requires a working encryption program; see
[EncryptProgram](EncryptProgram.md). If no key is configured, the PGP path
returns a "NEED ENCRYPTION KEY POINTER" error rather than encrypting.

## See also

[EncryptProgram](EncryptProgram.md), [PGP](PGP.md),
[CreditCardAuto](CreditCardAuto.md), the
[payments](../guides/payments.md) and [security](../guides/security.md) guides.

## Source

Stored as a raw string (no parser) from `catalog_directives()` in
`lib/Vend/Config.pm`; consumed in `lib/Vend/Order.pm` (`pgp_encrypt`) and
`lib/Vend/Payment.pm` (`$Vend::Cfg->{EncryptKey}`).
