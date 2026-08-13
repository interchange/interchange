# show_null

Makes embedded NUL characters visible by escaping them as a literal `\0`.

## Syntax

    [filter show_null]TEXT[/filter]
    [value name=field filter="show_null"]

## Description

Interchange uses the ASCII NUL character (`\0`) to join the several values
of a multivalued form control, but a NUL is invisible when printed. The
`show_null` filter replaces each NUL with the two-character sequence
backslash-zero (`\0`) so you can see where the separators fall -- useful
when debugging multivalued fields. No other characters are changed.

## Examples

Given a value with NUL separators (shown here as `\0`), such as
`"red\0green\0blue"`, applying the filter:

    [value name=colors filter="show_null"]

produces:

    red\0green\0blue

with each separator now printed as the literal characters `\0`.

## See also

[null_to_space](null_to_space.md), [null_to_comma](null_to_comma.md),
[nullselect](nullselect.md)

## Source

Defined in `code/Filter/show_null.filter`.
