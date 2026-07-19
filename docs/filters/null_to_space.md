# null_to_space

Replaces NUL characters in the value with a single space.

## Syntax

    [value name=field filter="null_to_space"]

## Description

Interchange joins the several values of a multivalued form control (a
multiple-select box, a set of same-named checkboxes) into one string with
ASCII NUL (`\0`) characters between them. The `null_to_space` filter
converts each run of NUL into a single space, flattening the values into a
space-separated scalar.

## Examples

Given a multiple-select control named `sizes` whose chosen values are
joined internally as `"S\0M\0L"`, applying the filter:

    [value name=sizes filter="null_to_space"]

produces:

    S M L

## Notes

The NUL character cannot be typed literally in an Interchange Tag Language
(ITL) page, so this filter is only meaningful on values Interchange itself
has NUL-joined from multivalued form input.

## See also

[null_to_colons](null_to_colons.md), [null_to_comma](null_to_comma.md),
[space_to_null](space_to_null.md)

## Source

Defined in `code/Filter/null_to_space.filter`.
