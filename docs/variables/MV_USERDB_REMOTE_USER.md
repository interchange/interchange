# MV_USERDB_REMOTE_USER

Treats any logged-in user as authorized, overriding the catalog's access
control lists. Reach for it only in tightly controlled environments where an
external authenticator (for example web-server authentication) already gates
access; it removes Interchange's own ACL checks.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_USERDB_REMOTE_USER  1

A boolean flag. Default: off.

## Description

`check_security()` consults `MV_USERDB_REMOTE_USER`. When it is enabled, a user
who is logged in is allowed to override all existing access control lists —
Interchange stops enforcing its per-page and per-item ACLs for that session.
This is intended for setups where authentication and authorization are handled
outside Interchange.

## Examples

Enable remote-user override for a catalog:

    Variable  MV_USERDB_REMOTE_USER  1

## Notes

Because this bypasses Interchange's ACL enforcement, enable it only when
something else is enforcing access. Combined with a misconfigured front end it
can expose protected pages.

## See also

[MV_NO_CRYPT](MV_NO_CRYPT.md), the
[user-database](../guides/user-database.md) and [security](../guides/security.md)
guides.

## Source

Consumed in `lib/Vend/Util.pm` (`check_security`) via
`$::Variable->{MV_USERDB_REMOTE_USER}`.
