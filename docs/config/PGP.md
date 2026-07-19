# PGP

Enables automatic PGP/GPG encryption of the complete order report before it
is mailed. Reach for it when order emails leave the server and must not be
readable in transit or at rest on the mail host.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    PGP  command [arguments]

The raw command string used to encrypt the order. It is stored verbatim
(no parser) and run as given. Default: empty (no encryption of the order
report).

## Description

When `PGP` is non-empty, Interchange pipes the assembled order report
through the given command before sending it to the address named by
[MailOrderTo](MailOrderTo.md). This is separate from, and in addition to,
any payment-field encryption performed for
[CreditCardAuto](CreditCardAuto.md). The check happens in
`lib/Vend/Order.pm`, which calls `pgp_encrypt` when `$Vend::Cfg->{PGP}` is
set.

The command must be able to encrypt without prompting: the keyring must be
readable by the Interchange daemon user (in that user's home directory or
at the path named by the `PGPPATH` environment variable), and the
recipient's public key must already be present and trusted. If the command
fails, the customer is shown the `failed` special page.

Despite the directive name, any command that reads plaintext on standard
input and writes ciphertext on standard output works, including GnuPG
(`gpg`).

## Examples

Encrypt orders to a recipient with classic PGP (in `catalog.cfg`):

```
PGP /usr/local/bin/pgp -feat orders@example.com
```

Encrypt with GnuPG:

```
PGP /usr/bin/gpg --batch -ea -r orders@example.com
```

## Notes

If the order [Route](Route.md) is configured with the `supplant` option,
that route takes over report handling and this directive is ignored.

The related [EncryptProgram](EncryptProgram.md) and
[EncryptKey](EncryptKey.md) directives control encryption of individual
fields (such as the credit card number) rather than the whole report.

## See also

[EncryptProgram](EncryptProgram.md), [EncryptKey](EncryptKey.md),
[CreditCardAuto](CreditCardAuto.md), [MailOrderTo](MailOrderTo.md),
[Route](Route.md), the [payments](../guides/payments.md) and
[security](../guides/security.md) guides.

## Source

Stored with no parser (raw string) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{PGP}` (through `pgp_encrypt`) in `lib/Vend/Order.pm`.
