# lc

Converts the entire input to lower case, honoring the session locale.

## Syntax

    [filter lc]TEXT[/filter]
    [value name=field filter="lc"]

`lower` is an alias for this filter; see [lower](lower.md).

## Description

The filter returns `lc($value)`. It enables Perl's `use locale`, and if the
scratch variable `mv_locale` is set it calls `POSIX::setlocale(LC_CTYPE, ...)`
with that locale first, so case folding follows the active locale's rules
rather than plain ASCII. Empty input yields empty output.

To lower-case only the first character, use [lcfirst](lcfirst.md); for upper
case, use [uc](uc.md).

## Examples

    [filter lc]YOU ARE INVITED[/filter]

produces:

    you are invited

## See also

- [lower](lower.md)
- [uc](uc.md)
- [lcfirst](lcfirst.md)
- [ucfirst](ucfirst.md)
- [namecase](namecase.md)

## Source

Defined in `code/Filter/lc.filter` (which also declares the alias `lower`).
