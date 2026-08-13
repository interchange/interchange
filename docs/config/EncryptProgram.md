# EncryptProgram

Selects the external program Interchange uses to encrypt data such as credit
card numbers. Reach for it to point Interchange at your GnuPG or PGP binary, or
to disable encryption entirely.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    EncryptProgram  program

Name the encryption program (a command name, a full path, or the literal
`none`).

### Global

In `interchange.cfg` the value is resolved to an actual executable: the parser
takes the first existing program from the candidate list, whose default is
`gpg`, then `pgpe`, then `none`. Default: the first of `gpg`/`pgpe`/`none`
found on the server.

### Catalog

In `catalog.cfg` the value is stored as a raw string. Its default is the global
`EncryptProgram` (or empty if none was resolved), so a catalog inherits the
server-wide choice unless it overrides it. Setting `none` disables encryption
for the catalog.

## Description

When Interchange encrypts data through `pgp_encrypt` (`lib/Vend/Order.pm`), it
runs the configured program. The program name is inspected and the appropriate
options are appended automatically:

- `gpg` -> `--batch --always-trust -e -a`, recipient given with `-r`
- `pgpe` -> `-fat`, recipient given with `-r`
- `pgp` -> `-fat -`, recipient appended directly

The recipient key comes from [EncryptKey](EncryptKey.md) (or an explicitly
passed key). You therefore normally set just the program name; the required
options are supplied for you.

In the order [Route](Route.md) path used by the standard demo, this directive
also provides the default value of the route `encrypt_program` attribute.

## Examples

Use GnuPG. In `catalog.cfg`:

```
EncryptProgram gpg
```

Give a full path when the binary is not on Interchange's `PATH`:

```
EncryptProgram /usr/local/bin/gpg
```

Disable encryption for a catalog:

```
EncryptProgram none
```

## Notes

Prefer a bare command name over a full path when the program is on the server's
`PATH`, to ease moving to a platform where the binary lives elsewhere.

This directive is not the same as [PGP](PGP.md), which encrypts a complete order
rather than individual fields.

Historic documentation described `%p` and `%f` placeholders (password and
temporary-file name) that could appear in the command line. The current
`pgp_encrypt` implementation does not perform any such placeholder substitution;
it recognizes the `gpg`/`pgpe`/`pgp` program name and appends the standard
options and recipient itself. Configure only the program name (and optionally a
path); do not rely on `%p`/`%f`.

## See also

[EncryptKey](EncryptKey.md), [PGP](PGP.md), [Route](Route.md),
[SendMailProgram](SendMailProgram.md), the
[payments](../guides/payments.md) and [security](../guides/security.md) guides.

## Source

Parsed by `parse_executable` (global) in `lib/Vend/Config.pm`; stored as a raw
string (catalog) from `catalog_directives()`. Consumed in
`lib/Vend/Order.pm` (`pgp_encrypt`) and `lib/Vend/Payment.pm`
(`$Vend::Cfg->{EncryptProgram}`).
