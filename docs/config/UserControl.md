# UserControl

Switches the catalog's user-database operations from the standard
`Vend::UserDB` module to the enhanced `Vend::UserControl` module. Reach for it
only when you need the extended account-handling behavior that module provides.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    UserControl  Yes|No

A boolean (`Yes`/`No`, `1`/`0`, `on`/`off`). Default: `No`.

## Description

User-database actions (login, account creation, saving shipping and billing
information, and so on) are normally handled by `Vend::UserDB`. When
`UserControl` is set, Interchange routes those operations through
`Vend::UserControl` instead, an enhanced variant of the same interface. The
choice is made where the user-database module is selected, so it applies to the
catalog's `userdb` operations as a whole.

## Examples

Enable the enhanced user functions (in `catalog.cfg`):

```
UserControl  Yes
```

## Notes

`UserControl` selects which module implements the user functions; it does not
by itself change the account schema. Use it only if you specifically require the
`Vend::UserControl` behavior, since the standard `Vend::UserDB` covers ordinary
account handling.

## See also

[UserDB](UserDB.md), [UserDatabase](UserDatabase.md), the
[user-database](../guides/user-database.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/UserDB.pm` via `$Vend::Cfg->{UserControl}`, which chooses
`Vend::UserControl` over `Vend::UserDB`.
