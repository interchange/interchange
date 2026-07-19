# sha1

Replaces the value with its SHA-1 digest, in hexadecimal.

## Syntax

    [filter sha1]TEXT[/filter]
    [value name=field filter="sha1"]

## Description

The filter returns the 40-character lowercase hexadecimal SHA-1 hash of the
input. It is commonly used to store a one-way hash of a password or other
secret rather than the plaintext. The empty string hashes to a fixed,
well-known value.

## Examples

    [filter sha1]One[/filter]

produces:

    b58b5a8ced9db48b30e008b148004c1065ce53b1

    [filter sha1]Two[/filter]

produces:

    16e018ece5a1d3b750531de58d16b961de23d629

An empty value hashes to the standard SHA-1 of the empty string:

    [filter sha1][/filter]

produces:

    da39a3ee5e6b4b0d3255bfef95601890afd80709

## Notes

The digest is computed by `Vend::Util::sha1_hex`, which uses the
`Digest::SHA` module (falling back to `Digest::SHA1`). If neither module is
installed, the filter logs an error and returns the input unchanged.

## See also

[md5](md5.md), [crypt](crypt.md), [bcrypt](bcrypt.md)

## Source

Defined in `code/Filter/sha1.filter`; digest via `sha1_hex` in
`lib/Vend/Util.pm`.
