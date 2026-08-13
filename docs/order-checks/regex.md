# regex

Checks that a field's value matches one or more regular expressions --
the general-purpose escape hatch for validation not covered by a named
check.

## Syntax

    FIELD=regex PATTERN [PATTERN ...] [message]

Used as the check name in an order-profile line. The admin catalog-creation
wizard (`dist/lib/UI/pages/include/wizard_profiles`) uses it to constrain a
two-letter state/country abbreviation:

    state=regex [A-Z][A-Z]
    country=regex [A-Z][A-Z]

## Description

The argument is split with shell-word rules, so a quoted trailing segment
becomes the custom `message` and everything before it is one or more
patterns, space-separated. Each pattern is compiled with `qr()` and matched
against the value with `=~`; prefixing a pattern with `!` negates it (the
check requires the value to *not* match). All patterns must pass for the
check to succeed -- the first one that fails stops evaluation.

If no custom `message` is given, the failure text is `failed pattern -
'VALUE' =~ PATTERN` (or `!~` for a negated pattern).

## Examples

Constrain a two-letter state abbreviation, as the admin wizard does:

    state=regex [A-Z][A-Z]

Validate a custom fiscal-data format with a specific message:

    fiscal_data=regex ^\d\d-[A-Z\d]{9}-\d{4}-[A-Z\d]{10}-\d{4}-\d{4}$ "Invalid format"

Require a value that does *not* contain the word "test", using negation:

    sku=regex "!test" "SKU may not contain the word 'test'"

## Notes

Because the argument is parsed with `Text::ParseWords::shellwords`, a
pattern containing spaces or shell metacharacters should be quoted, and a
literal backslash in the pattern needs its own escaping (the routine
doubles backslashes before parsing to keep `\d`, `\s`, and similar regex
escapes intact).

## See also

[filter](filter.md), [match](match.md), [error](../tags/error.md),
[OrderProfile](../config/OrderProfile.md),
the [cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Defined in `code/OrderCheck/regex.oc`. The routine takes
`($ref, $name, $value, $code)`, parses one or more patterns (and an
optional trailing quoted message) with `Text::ParseWords::shellwords`, and
matches each `qr($pattern)` against `$value`.
