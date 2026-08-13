# null_to_colons

Replaces NUL characters in the value with a double colon (`::`).

## Syntax

    [value name=field filter="null_to_colons"]

## Description

Interchange joins the several values of a multivalued form control (a
multiple-select box, a set of same-named checkboxes) into one string with
ASCII NUL (`\0`) characters between them. The `null_to_colons` filter
converts each run of NUL into `::`, giving a colon-delimited scalar that is
convenient to store in a single database column or to feed to code that
expects the `::` separator. It is the inverse of
[colons_to_null](colons_to_null.md).

## Examples

Given a multiple-select control named `sizes` whose chosen values are
joined internally as `"S\0M\0L"`, applying the filter:

    [value name=sizes filter="null_to_colons"]

produces:

    S::M::L

## Notes

The NUL character cannot be typed literally in an Interchange Tag Language
(ITL) page, so this filter is only meaningful on values Interchange itself
has NUL-joined from multivalued form input.

## See also

[colons_to_null](colons_to_null.md), [null_to_comma](null_to_comma.md),
[null_to_space](null_to_space.md)

## Source

Defined in `code/Filter/null_to_colons.filter`.
