# word

Removes every non-word character, keeping only letters, digits, and
underscores.

## Syntax

    [filter word]TEXT[/filter]
    [value name=field filter="word"]

`word` takes no arguments.

## Description

The filter deletes every run of non-word characters, using the Perl `\W`
character class — that is, it keeps only characters in `A-Z`, `a-z`, `0-9`, and
`_`, and removes everything else (spaces, punctuation, and symbols). The kept
characters are joined directly together with no separator. This is handy for
reducing arbitrary input to a bare identifier.

## Examples

    [filter word]Hello, World![/filter]

produces:

    HelloWorld

Underscores and digits are kept:

    [filter word]user_name #42[/filter]

produces:

    user_name42

## See also

- [alpha](alpha.md) — keep only letters
- [alphanumeric](alphanumeric.md) — keep only letters and digits
- [digits](digits.md) — keep only digits
- [filesafe](filesafe.md) — sanitize a value for use as a file name

## Source

Defined in `code/Filter/word.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
