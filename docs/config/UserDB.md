# UserDB

Defines named *profiles* that control Interchange's built-in user database
system -- customer logins, account creation, saved carts, address books,
and access control. Reach for it to tune how the [userdb](../tags/userdb.md)
tag behaves: which table and fields it uses, how passwords are encrypted,
and what validation it applies.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    UserDB  profile  parameter  value

Three tokens: the profile name, a parameter name, and the value.
`UserDB` is parsed by `parse_locale`, so each line adds one
`parameter => value` pair to the named profile, and repeated lines build a
profile up incrementally. A profile name of `default` supplies the settings
used when the `userdb` tag is called without an explicit `profile=`.
Default: empty (Interchange provides built-in defaults for each parameter).

## Description

Each profile is a set of parameters stored in the catalog's
`UserDB_repository`. When the [userdb](../tags/userdb.md) tag runs a
function (login, new account, save values, and so on), it selects a profile
by name -- `default` unless overridden with `profile=` on the tag -- and
uses that profile's parameters. Anything not set falls back to the
compiled-in default shown below.

The most commonly set parameters:

| Parameter    | Default        | Meaning                                       |
|--------------|----------------|-----------------------------------------------|
| `database`   | `userdb`       | Table holding user records                    |
| `pass_field` | `password`     | Column storing the (encrypted) password       |
| `crypt`      | `1`            | Encrypt passwords (`0` stores them plain)     |
| `md5`        | `0`            | Use MD5 instead of Unix `crypt`               |
| `ignore_case`| `0`            | Case-insensitive username/password matching   |
| `userminlen` | `2`            | Minimum username length                       |
| `passminlen` | `4`            | Minimum password length                       |
| `time_field` | `mod_time`     | Column storing last-login time                |
| `expire_field`| `expiration`  | Column storing account expiration             |
| `scratch`    | (none)         | Fields loaded into scratch instead of values  |
| `outboard`   | (none)         | Fields that live in a separate table          |
| `assign_username`| `0`        | Auto-assign a username when none is supplied  |
| `indirect_login`| (none)      | Alternate login column (not the table key)    |
| `logfile`    | `error.log`    | Where login successes/failures are logged     |
| `super_field`| `super`        | Column marking a superuser account            |

More parameters exist (address-book, cart, and preference field names;
access-control columns `acl`/`db_acl`/`file_acl`; `validchars`;
`username_mask`; and others); see the [userdb](../tags/userdb.md) tag page
for the full list. Any parameter can also be overridden per call by passing
it as an attribute to the `userdb` tag.

At the end of configuration Interchange scans every profile: profiles
carrying an `admin` setting are collected into the catalog's `AdminUserDB`
map, and if a profile requests SHA1 encryption but no `Digest::SHA` /
`Digest::SHA1` module is available, catalog configuration fails with an
error.

## Examples

Store passwords in the clear for the `default` profile but encrypt with MD5
for an `admin` profile (in `catalog.cfg`):

```
UserDB  default  crypt   0
UserDB  admin    crypt   1
UserDB  admin    md5     1
```

Require longer usernames and passwords:

```
UserDB  default  userminlen  8
UserDB  default  passminlen  6
```

Load selected fields into scratch space rather than the values space:

```
UserDB  default  scratch  "dealer price_level credit_limit"
```

Override a parameter at call time from a page, without touching
`catalog.cfg`:

```
[userdb function=new_account userminlen=6]
```

## Notes

`UserDB` configures the login/account system; it is separate from
[UserDatabase](UserDatabase.md), which names the table used for the older
HTTP Basic-authentication check. The table a `UserDB` profile reads is set
with its `database` parameter (default `userdb`) and must be defined with a
[Database](Database.md) directive.

## See also

[userdb](../tags/userdb.md), [UserDatabase](UserDatabase.md),
[UserControl](UserControl.md), [Database](Database.md),
[ValuesDefault](ValuesDefault.md), the
[user-database](../guides/user-database.md) guide.

## Source

Parsed by `parse_locale` in `lib/Vend/Config.pm` (stored in
`$C->{UserDB_repository}`, post-processed to build `AdminUserDB` and check
SHA1 availability); consumed by `lib/Vend/UserDB.pm` via the
[userdb](../tags/userdb.md) tag.
