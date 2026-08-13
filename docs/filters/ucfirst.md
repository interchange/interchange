# ucfirst

Upper-cases the first character of the value, leaving the rest unchanged.

## Syntax

    [filter ucfirst]TEXT[/filter]
    [value name=field filter="ucfirst"]

`ucfirst` takes no arguments.

## Description

The filter upper-cases only the first character of the value using Perl's
`ucfirst` function under `use locale`. If the scratch variable `mv_locale` is
set, the filter calls `POSIX::setlocale(LC_CTYPE, ...)` with that locale first,
so locale-specific letter mappings are honored. The remaining characters are
left exactly as they are — unlike title-casing, it does not touch later words
or lower-case the rest of the string.

## Examples

    [filter ucfirst]hello[/filter]

produces:

    Hello

Only the first character is affected:

    [filter ucfirst]hello WORLD[/filter]

produces:

    Hello WORLD

## See also

- [lcfirst](lcfirst.md) — lower-case the first character
- [uc](uc.md) — upper-case the whole value
- [namecase](namecase.md) — title-case a name

## Source

Defined in `code/Filter/ucfirst.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
