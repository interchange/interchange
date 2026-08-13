# uc

Converts the value to upper case.

## Syntax

    [filter uc]TEXT[/filter]
    [value name=field filter="uc"]

`uc` takes no arguments. The name `upper` is an alias for this filter (see
[upper](upper.md)).

## Description

The filter upper-cases the entire value using Perl's `uc` function under
`use locale`. If the scratch variable `mv_locale` is set, the filter calls
`POSIX::setlocale(LC_CTYPE, ...)` with that locale first, so locale-specific
letter mappings are honored. Characters that have no upper-case form are left
unchanged.

## Examples

    [filter uc]interchange[/filter]

produces:

    INTERCHANGE

Only cased characters change:

    [filter uc]Order #A12-b[/filter]

produces:

    ORDER #A12-B

## See also

- [upper](upper.md) — alias for this filter
- [lower](lower.md) / [lc](lc.md) — the lower-case counterpart
- [ucfirst](ucfirst.md) — upper-case only the first character
- [namecase](namecase.md) — title-case a name
- [internationalization](../guides/internationalization.md) — locale handling

## Source

Defined in `code/Filter/uc.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
