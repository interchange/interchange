# option_format

Converts Interchange's internal NUL-delimited option triples into a
`value=label*` option string.

## Syntax

    [value name=field filter="option_format"]
    [value name=field filter="option_format.DELIM"]

## Description

Interchange represents the choices of an option widget internally as a flat
list of NUL-separated (`\0`) fields, three per option: the stored value,
the display label, and a default flag. The `option_format` filter takes
that list, three fields at a time, and renders each option as
`value=label`, appending `*` when the default flag is set. Options with no
value and no label are skipped. The rendered options are then joined with a
delimiter.

The value is returned unchanged unless it contains at least two NUL
characters, so ordinary text is never altered.

The optional dotted `DELIM` argument chooses the separator between options.
It is matched by keyword:

| Argument   | Delimiter |
|------------|-----------|
| (none)     | `,` (comma) |
| `pipe`     | `|`       |
| `semicolon`| `;`       |
| `colon`    | `:`       |
| `null`     | NUL (`\0`)|

When the default comma delimiter is used, any comma inside a label is
escaped to `&#44;` so it does not clash with the separator; the other
delimiters do not perform this escaping.

## Examples

Given an internal option list of two options -- value `red` labeled `Red`,
and value `blue` labeled `Blue` and marked as the default -- the filter:

    [value name=color filter="option_format"]

produces:

    red=Red,blue=Blue*

Using the pipe delimiter instead:

    [value name=color filter="option_format.pipe"]

produces:

    red=Red|blue=Blue*

## Notes

This filter is part of the option-widget machinery (see the
[option_format](../widgets/option_format.md) widget); it operates on the
NUL-delimited internal form, which cannot be typed literally in a page, so
the examples above are illustrative of the transformation rather than
copy-and-paste page text.

## See also

[options2line](options2line.md), [line2options](line2options.md),
[nullselect](nullselect.md)

## Source

Defined in `code/Filter/option_format.filter`.
