# strip

Trims leading and trailing whitespace from the value.

## Syntax

    [filter strip]TEXT[/filter]
    [value name=field filter="strip"]

`strip` takes no arguments. It can be applied through any `filter=` attribute
and chained with other filters by separating names with whitespace (for
example `filter="strip yesno"` strips first, then tests the result).

## Description

The filter removes any run of leading whitespace and any run of trailing
whitespace, using the Perl `\s` character class (spaces, tabs, carriage
returns, newlines, and form feeds). Whitespace **inside** the value is left
untouched. Input that is empty or entirely whitespace becomes the empty
string.

## Examples

Trim surrounding spaces:

    [filter strip]  hello  [/filter]

produces:

    hello

Interior whitespace is preserved:

    [filter strip]   one   two   [/filter]

produces:

    one   two

Strip before another filter so blank-but-spaced input reads as empty:

    [filter strip yesno]   [/filter]

produces:

    No

(Without `strip`, the whitespace-only body is a true value and
[yesno](yesno.md) would return `Yes`.)

## See also

- [compress_space](compress_space.md), [no_white](no_white.md) — collapse or
  remove interior whitespace
- [oneline](oneline.md) — truncate at the first line break

## Source

Defined in `code/Filter/strip.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
