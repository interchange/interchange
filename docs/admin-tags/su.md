# su

Switch the current session to another user's identity ("switch user"), and later
switch back, so a catalog superuser can act as a customer or another
administrator. It is the mechanism behind the admin UI's "become this user"
feature. This tag is part of the admin UI toolset (registered from
`code/UI_Tag/` and loaded only when the administrative interface is enabled),
not a storefront tag.

## Syntax

    [su username]
    [su user=jdoe]
    [su username=jdoe create_user=1]
    [su exit=1]

Standalone tag (no end tag). Returns a true value on success, or undefined on a
permission failure or error (with an explanation stored in `ui_error`).

## Attributes

| Attribute     | Default   | Description |
|---------------|-----------|-------------|
| `username`    | none      | User to switch to. Alias: `user` for `username`. |
| `profile`     | default   | UserDB repository profile to look the user up in; `admin` forces profile `ui`. |
| `admin`       | off       | Switch to the target as an administrative user (requires superuser privilege). |
| `create_user` | off       | If the target user does not exist, create the account before switching. |
| `exit`        | off       | Return from a previous `su`, restoring the saved superuser session. |

Positional order: `username`. Remaining named attributes are collected as
options (`addAttr`).

## Description

The tag resolves the user database from the chosen `profile` (or the catalog's
default `UserDB`), using that repository's `database` and `user_field`
settings. Two privilege rules are enforced before any switch:

- Switching *to an administrative user* (`admin`, or a repository marked admin)
  requires the current session to pass the `super` check.
- Switching to any user at all requires the current session to be an admin
  session (`$Vend::admin`).

On a switch, the tag saves the current session, writes a keyed cookie
(`MV_SU_KEY`) and a matching check file under `$Global::ConfDir/tmp`, then starts
a fresh session as the target user. With `create_user` set and no such user, it
first creates the account through the [userdb](../tags/userdb.md) tag's
`new_account` call. The original session is stashed so that a later `[su exit=1]`
can restore it: `exit` verifies the cookie against the saved check file and, on
a match, reinstates the superuser's session and identity. Every switch and
return is written to the error log for audit.

## Examples

Switch to a customer account (from an admin session):

    [su username=jdoe]

Switch to another administrator (requires superuser):

    [su username=backupadmin admin=1]

Create the account on the fly if it does not exist, then become it:

    [su user=newcustomer create_user=1]

Return to the original superuser identity:

    [su exit=1]

## Notes

This tag changes who the session is authenticated as; treat it as
security-sensitive and expose it only on properly gated admin pages. Failures
are deliberately quiet to the page (they return undefined and log the reason);
check `ui_error` for the message. The return path depends on the `MV_SU_KEY`
cookie and the check file under `$Global::ConfDir/tmp`, so cookies must be
enabled for `[su exit=1]` to work.

## See also

- [userdb](../tags/userdb.md)
- [if_mm](if_mm.md)
- Concepts: [user database](../guides/user-database.md),
  [security](../guides/security.md), [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/su.coretag`, registered as the UserTag `su` (inline
Routine).
