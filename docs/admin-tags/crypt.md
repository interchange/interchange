# crypt

Encrypt a string with Perl's built-in `crypt()`, exactly like the C library
`crypt(3)` function. Used in the admin UI (and anywhere) to hash or verify a
password. This tag is part of the Interchange admin UI toolset (the tags in
`code/UI_Tag/`, loaded when the admin UI feature is enabled), not a storefront
tag.

## Syntax

    [crypt value]
    [crypt value salt]
    [crypt value=STRING salt=SALT]

Standalone tag (no end tag). The return value is the crypted string; it is not
reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute | Default             | Description |
|-----------|---------------------|-------------|
| `value`   | none                | Text to encrypt. |
| `salt`    | random 2-character  | Salt for the crypt. Leave empty to let the tag generate a random 2-character salt; supply it when verifying an existing hash. |

Positional order: `value`, `salt`.

Aliases: `password` for `value`; `crypted` for `salt`.

## Description

`[crypt]` calls Perl's `crypt(value, salt)`. When `salt` is not given, the tag
generates a random 2-character salt with `Vend::Util::random_string(2)`, so each
call produces a different hash of the same input.

`crypt` is a one-way function: there is no decrypt. To verify a password,
re-run `[crypt]` on the candidate plaintext using the stored hash as the salt,
and compare the result to the stored hash; if they match, the password is
correct. This works because the salt is the leading part of a crypt hash.

## Examples

Hash a value with a generated salt:

    [crypt value="secret"]

Verify a value against a stored hash by using the hash as the salt:

    [seti stored][crypt value="secret"][/seti]
    [if type=explicit
        compare="[crypt value='secret' salt='[scratch stored]']"
             eq="[scratch stored]"]
      Password matches.
    [else]
      Password does not match.
    [/if]

The same idea in Perl:

    [perl]
      $Tag->crypt("secret", $Scratch->{stored}) eq $Scratch->{stored}
        ? "Password matches." : "Password does not match.";
    [/perl]

## Notes

Traditional `crypt(3)` considers only the first eight characters of the input
and produces a short hash; it is not suitable for encrypting bulk data and is
weak by modern standards. For new password storage prefer a stronger scheme
where available (see the user-database password handling).

If you supply your own salt, draw its characters from the set
`[./0-9A-Za-z]`.

## See also

- [add_gpg_key](add_gpg_key.md)
- Concepts: [user database](../guides/user-database.md),
  [security](../guides/security.md)

## Source

Defined in `code/UI_Tag/crypt.coretag`. Implemented by the inline Routine,
which calls Perl's `crypt()` and `Vend::Util::random_string`.
