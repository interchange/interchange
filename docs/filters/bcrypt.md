# bcrypt

Hashes a password with bcrypt, using a [UserDB](../guides/user-database.md)
profile's cost and settings.

## Syntax

    [filter bcrypt]PASSWORD[/filter]
    [filter bcrypt.PROFILE]PASSWORD[/filter]
    [value name=password filter="bcrypt"]

The optional dotted argument `PROFILE` names the UserDB profile whose
bcrypt settings (such as the work cost) are used. When omitted it defaults
to the profile named `default`.

## Description

The filter passes the value to `Vend::UserDB::construct_bcrypt`, which
produces a bcrypt password hash string (the modular-crypt format beginning
`$2`). The named profile — or `default` if none is given — supplies the
bcrypt parameters. Because bcrypt incorporates a random salt, the output
differs on every call; you verify a password by re-hashing the candidate
against the stored value.

bcrypt is the recommended one-way hash for password storage, and is
stronger than the DES-based [crypt](crypt.md).

This filter relies on Interchange catalog internals and **will not work
from an embedded Perl block** unless that block runs as global Perl.

## Examples

    [filter bcrypt]seekrit[/filter]

produces a bcrypt hash such as:

    $2a$13$e0MYzXyjpJS7Pd0RVvHwHe1Rpbab/A
    lC5UwtoTaA5.9SS6Gxq6h6

(a single line in practice; the exact string, including its random salt,
differs on each run).

Selecting a UserDB profile explicitly:

    [filter bcrypt.default]seekrit[/filter]

## See also

- [crypt](crypt.md)
- [sha1](sha1.md)
- [md5](md5.md)
- [user database guide](../guides/user-database.md)

## Source

Defined in `code/Filter/bcrypt.filter`. The hash is built by
`Vend::UserDB::construct_bcrypt` in `lib/Vend/UserDB.pm`.
