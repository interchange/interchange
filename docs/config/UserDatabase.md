# UserDatabase

Names the database table Interchange consults to verify passwords for HTTP
Basic authentication. Reach for it when you protect pages with the
server's `RemoteUser`/Basic-auth mechanism and want the credentials checked
against a table rather than a single hardcoded password.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    UserDatabase  table_name

A single database table name. The value is stored verbatim (no parser
runs). Default: empty.

## Description

When a request arrives with an HTTP `Authorization: Basic` header,
`check_authorization` in `lib/Vend/Util.pm` decodes the supplied username
and password. If the username is not the catalog's single
[RemoteUser](RemoteUser.md) account, Interchange looks up the password in
the table named by `UserDatabase`:

```perl
$pwinfo = $Vend::Cfg->{UserDatabase} unless $pwinfo;
$cmp_pw = Vend::Interpolate::tag_data($pwinfo, 'password', $user)
    if defined $Vend::Cfg->{Database}{$pwinfo};
```

The table must have a `password` field keyed by username; the stored value
is compared with `crypt` unless the `MV_NO_CRYPT` [Variable](Variable.md)
is set. The named table must already be defined with a
[Database](Database.md) directive.

This is the low-level Basic-auth path and is distinct from the richer
session-login system configured with [UserDB](UserDB.md). Most catalogs use
`UserDB` for customer logins and leave `UserDatabase` unset.

## Examples

Point Basic-auth password checks at a `userdb` table (in `catalog.cfg`):

```
Database      userdb  userdb.txt  TAB
UserDatabase  userdb
```

## Notes

If `UserDatabase` is empty and no explicit table is passed to the
authorization check, no table lookup occurs and Basic-auth users other than
`RemoteUser` are rejected. Prior documentation listed the default as
`userdb`; the current code defaults it to empty, so name the table
explicitly.

## See also

[UserDB](UserDB.md), [Database](Database.md), [RemoteUser](RemoteUser.md),
[Password](Password.md), the [user-database](../guides/user-database.md) and
[security](../guides/security.md) guides.

## Source

Stored unparsed (parser `undef`) by the catalog `UserDatabase` directive in
`lib/Vend/Config.pm`; consumed by `check_authorization` in
`lib/Vend/Util.pm`.
