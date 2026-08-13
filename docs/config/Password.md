# Password

Sets the encrypted password that authorizes protected catalog operations, most
notably remote reconfiguration and access under [RemoteUser](RemoteUser.md).
Reach for it to guard the catalog's administrative entry points with a shared
secret.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Password  encrypted-password

A single encrypted-password string, stored as-is (no parser). Default: empty (no
password check). The value is a standard Unix `crypt` hash unless the
[MV_NO_CRYPT](../variables/MV_NO_CRYPT.md) variable is set, in which case it is
compared as plain text.

## Description

`lib/Vend/Util.pm` consults `Password` in two places. When a request tries to
reconfigure the catalog, the supplied password is `crypt`ed and compared with the
stored value; a mismatch is logged as an alert and the reconfigure is refused.
When HTTP authentication is used with [RemoteUser](RemoteUser.md), the presented
credentials are checked against `Password` the same way.

`Password` is one of three controls -- alongside [MasterHost](MasterHost.md) and
[RemoteUser](RemoteUser.md) -- that gate secure operations. If none of the three
is set, those operations are disabled outright rather than left open.

Because the stored value is a hash, you generate it with a crypt utility rather
than typing the plaintext. For example:

```sh
perl -le 'print crypt("mypasswd", "AA")'
```

where `AA` is a two-character salt.

## Examples

Set a catalog password (a hash of an empty password shown for illustration, in
`catalog.cfg`):

```
Password bAWoVkuzphOX.
```

## Notes

Store only the encrypted form in `catalog.cfg`; never the plaintext. Set
[MV_NO_CRYPT](../variables/MV_NO_CRYPT.md) only if you understand that it makes
the value a cleartext comparison.

## See also

[RemoteUser](RemoteUser.md), [MasterHost](MasterHost.md),
[MV_NO_CRYPT](../variables/MV_NO_CRYPT.md), [crypt](../filters/crypt.md), the
[security](../guides/security.md) guide.

## Source

Parsed with no parser (raw string) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{Password}` in `lib/Vend/Util.pm`.
