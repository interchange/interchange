# encrypt

PGP/GPG-encrypts the input using the catalog's configured encryption program
and key, returning the ASCII-armored ciphertext.

## Syntax

    [filter encrypt]TEXT[/filter]
    [filter encrypt.KEY]TEXT[/filter]
    [filter encrypt.KEY.PROGRAM]TEXT[/filter]

The dotted arguments are optional:

| Argument  | Meaning                                         | Default                              |
|-----------|-------------------------------------------------|--------------------------------------|
| `KEY`     | Recipient key id (or space/comma-separated ids) | [EncryptKey](../config/EncryptKey.md) |
| `PROGRAM` | Path to the encryption binary                   | [EncryptProgram](../config/EncryptProgram.md) |

## Description

The filter hands the input to `Vend::Order::pgp_encrypt`, which builds and runs
an external encryption command. The command line is assembled automatically
from the recognized program name; you cannot pass your own command-line
options, and you do not need to:

- `gpg` → `gpg --batch --always-trust -e -a -r KEY`
- `pgpe` → `pgpe -fat -r KEY`
- `pgp` → `pgp -fat - KEY`

Multiple key ids may be given separated by spaces or commas; each is passed
with its own recipient flag. The result is the program's ASCII-armored output.

This filter is the mechanism behind Interchange's encrypt-in-place handling of
sensitive form fields (most commonly credit-card numbers). It requires a
working GnuPG/PGP installation and a configured key; without them the filter
returns an error message such as `NEED ENCRYPTION ENABLED.` or
`NEED ENCRYPTION KEY POINTER.` instead of ciphertext. A command containing a
shell metacharacter (`;` or `|`) causes a fatal error rather than running.

Because the output depends on your keyring, it is not deterministic and no
literal output is shown here.

## Examples

Encrypt using a specific key id:

    [filter encrypt.your_key_id]4111 1111 1111 1111[/filter]

Encrypt using a specific key id and an explicit gpg binary:

    [filter encrypt.your_key_id./usr/local/bin/gpg]Secret phrase[/filter]

Using the catalog defaults (`EncryptKey` and `EncryptProgram` from
`catalog.cfg`):

    [filter encrypt]4111 1111 1111 1111[/filter]

## See also

- [md5](md5.md)
- [sha1](sha1.md)
- [EncryptProgram](../config/EncryptProgram.md)
- [EncryptKey](../config/EncryptKey.md)
- [Security guide](../guides/security.md)
- [Payments guide](../guides/payments.md)

## Source

Defined in `code/Filter/encrypt.filter`; the routine calls
`Vend::Order::pgp_encrypt` in `lib/Vend/Order.pm`.
