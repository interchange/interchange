# last_non_null

Splits the input on NUL characters and returns the last non-empty field — used
to pull a single value out of a null-joined combo/multiple submission.

## Syntax

    [filter last_non_null]TEXT[/filter]
    [value name=field filter="last_non_null"]

## Description

HTML controls that submit several values for one field name (multiple-select
boxes, combo widgets, groups of checkboxes) arrive in Interchange as a single
string with the individual values joined by NUL bytes (`\0`). This filter
splits that string on runs of NUL, reverses the list, and returns the first
element that has non-zero length — that is, the **last** non-empty value in the
original order. Trailing empty fields are skipped. If every field is empty (or
the input is empty), it returns an empty string.

Contrast with a plain combo where you want the first value; last_non_null is
the "reverse combo" case, useful when the meaningful entry is the most recent
one appended.

## Examples

Using the [filter](../tags/filter.md) tag from Perl, where `\0` can be written
literally:

    [perl]
        return $Tag->filter({
            op   => 'last_non_null',
            body => "One\0Two\0Three\0\0\0",
        });
    [/perl]

produces:

    Three

The three trailing NUL-separated empty fields are skipped, and `Three` — the
last non-empty field — is returned.

## See also

- [nullselect](nullselect.md)
- [null_to_comma](null_to_comma.md)
- [line](line.md)

## Source

Defined in `code/Filter/last_non_null.filter`.
