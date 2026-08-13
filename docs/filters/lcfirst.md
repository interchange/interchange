# lcfirst

Converts the first character of the input to lower case, leaving the rest
unchanged, honoring the session locale.

## Syntax

    [filter lcfirst]TEXT[/filter]
    [value name=field filter="lcfirst"]

## Description

The filter returns `lcfirst($value)`, which lower-cases only the first
character. It enables Perl's `use locale`, and if the scratch variable
`mv_locale` is set it calls `POSIX::setlocale(LC_CTYPE, ...)` with that locale
first. Empty input yields empty output; the remaining characters are untouched.

For the whole string, use [lc](lc.md); to upper-case the first character, use
[ucfirst](ucfirst.md).

## Examples

    [filter lcfirst]ABC DEF[/filter]

produces:

    aBC DEF

## See also

- [lc](lc.md)
- [ucfirst](ucfirst.md)
- [uc](uc.md)
- [namecase](namecase.md)

## Source

Defined in `code/Filter/lcfirst.filter`.
