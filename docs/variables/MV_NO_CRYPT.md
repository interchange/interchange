# MV_NO_CRYPT

Disables password hashing (crypt/MD5) for user accounts, storing and comparing
passwords in the clear. Reach for it only in narrow migration or testing
scenarios; it weakens account security and is retained mainly for legacy
catalogs.

**Scope:** catalog (`catalog.cfg`) or global (`interchange.cfg`)

## Syntax

    Variable  MV_NO_CRYPT  1

A boolean flag. Default: `0` (hashing enabled).

## Description

When `MV_NO_CRYPT` is true, Interchange skips the `crypt()` call and/or MD5
hashing it would normally apply to user passwords, both when writing new
passwords and when checking a login. Set globally it affects the whole server;
set in a `catalog.cfg` it affects that catalog.

## Examples

Disable password hashing for a catalog:

    Variable  MV_NO_CRYPT  1

## Notes

This is a legacy setting and could be removed in a future release. Leaving it
off (the default) is strongly preferred so passwords are stored hashed.

## See also

[MV_USERDB_REMOTE_USER](MV_USERDB_REMOTE_USER.md), the
[user-database](../guides/user-database.md) and [security](../guides/security.md)
guides.

## Source

Consumed in `lib/Vend/UserDB.pm` and `lib/Vend/Util.pm` via
`$::Variable->{MV_NO_CRYPT}`.
