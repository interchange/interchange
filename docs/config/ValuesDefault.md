# ValuesDefault

Sets default entries in every user session's values space, used until the
user (or a login) overrides them. Reach for it to preseed form fields and
session values -- a default country, shipping mode, or greeting -- for
brand-new visitors.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ValuesDefault  name  value

`name value` pairs parsed by `parse_hash` into a hash; each line adds one
entry (or several key/value pairs on one line). Default: empty.

## Description

At session initialization Interchange copies the `ValuesDefault` hash into
the new session's values space:

```perl
'values' => { %{$Vend::Cfg->{ValuesDefault}} },
```

Those values are then readable with the [value](../tags/value.md) tag (and
as `$Values->{name}` in embedded Perl) exactly like any user-supplied form
value. Because they are only defaults, anything the visitor submits -- or
anything loaded from the user database at login -- overrides them. When a
user logs in, [UserDB](UserDB.md) also restores stored values, but for
fields present in `ValuesDefault` and absent from the user record the
default remains.

## Examples

Set default name, last name, and country (in `catalog.cfg`):

```
ValuesDefault  fname     New
ValuesDefault  lname     User
ValuesDefault  country   US
```

Read them on a page:

```
Welcome!
Your first name is: [value fname]
Your country code is: [value country]
```

produces:

    Welcome!
    Your first name is: New
    Your country code is: US

Preselect a shipping mode:

```
ValuesDefault  mv_shipmode  UPS
```

## See also

[value](../tags/value.md), [ScratchDefault](ScratchDefault.md),
[UserDB](UserDB.md), the [forms](../guides/forms.md) and
[sessions](../guides/sessions.md) guides.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm`; consumed by
`lib/Vend/Session.pm` when a session's values space is initialized.
