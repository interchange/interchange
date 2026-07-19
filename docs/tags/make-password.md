# make-password

Generate a random, reasonably pronounceable password string. Reach for it
when creating an initial account password, a reset token, or any short
random credential to hand to a user.

## Syntax

    [make-password]

Standalone tag (no end tag). Returns the generated password string.

## Attributes

This tag takes no attributes. The generator reads no arguments; length and
character mix are determined by the algorithm.

## Description

`[make-password]` builds a password from alternating consonant/vowel
syllables and digit groups, chosen to be easy to read aloud while avoiding
ambiguous characters:

- Consonants exclude `l` and `y`; vowels are `a e i o u`; digits are `2`–`9`
  (excluding `0` and `1`).
- It assembles three segments. Each segment is either a
  consonant+vowel(+consonant) syllable or a one-or-two digit run, chosen at
  random, with logic that guarantees the result contains both letters and
  digits and does not place two digit-runs adjacent.
- The final segment is regenerated until the whole password is at least 8
  characters long.

The result therefore always mixes letters and numbers, avoids the
easily-confused characters `l`, `y`, `0`, and `1`, and is at least 8
characters. Output is random, so it differs on every call (for example
`fizo47bek`, `ted9moza`).

## Examples

Generate a password inline:

    [make-password]

Set a new user's password to a generated value when creating the account:

    [seti new_pass][make-password][/seti]
    [userdb function=new_account username="[value username]"
        password="[scratch new_pass]"]
    Your temporary password is: [scratch new_pass]

## Notes

- Because the character set is deliberately restricted for readability, the
  entropy per character is lower than a fully random string; it is aimed at
  human-usable temporary passwords, not high-security secrets.
- Any attributes you pass are ignored — the length and format are fixed by
  the algorithm.

## See also

- [userdb](userdb.md) — account creation and password management
- [../guides/user-database.md](../guides/user-database.md)

## Source

Defined in `code/UserTag/make_password.tag` (registers the tag
`make-password`). Implemented by an inline Routine.
