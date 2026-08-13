# md5

Returns the MD5 digest of the input as a 32-character lowercase hexadecimal
string.

## Syntax

    [filter md5]TEXT[/filter]
    [value name=field filter="md5"]

## Description

The filter returns `Digest::MD5::md5_hex($value)` — the MD5 hash of the input
rendered as hex. The output is always 32 hex characters and is deterministic
for a given input (the empty string hashes to
`d41d8cd98f00b204e9800998ecf8427e`).

MD5 is a fixed-length fingerprint, useful for cache keys, change detection, and
non-security checksums. It is **not** collision-resistant and must not be used
for password storage or other security purposes; use
[bcrypt](bcrypt.md) for passwords and [sha1](sha1.md) or the
[encrypt](encrypt.md) filter where appropriate.

## Examples

    [filter md5]One[/filter]

produces:

    06c2cea18679d64399783748fa367bdd

An empty input hashes to the well-known empty-string digest:

    [filter md5][/filter]

produces:

    d41d8cd98f00b204e9800998ecf8427e

## See also

- [sha1](sha1.md)
- [bcrypt](bcrypt.md)
- [crypt](crypt.md)
- [encrypt](encrypt.md)

## Source

Defined in `code/Filter/md5.filter`; uses `Digest::MD5`.
