# name

Rewrites a `Last, First` name into `First Last` order.

## Syntax

    [filter name]TEXT[/filter]
    [value name=field filter="name"]

Combine with other filters by listing them in `op`, applied left to right:

    [filter op="name namecase"]TEXT[/filter]

## Description

If the input contains a comma, the filter splits it once on the comma
(ignoring surrounding whitespace) and returns the second part followed by
the first: `Last, First` becomes `First Last`. Input with no comma is
returned unchanged, so the filter is safe to apply to values that may
already be in `First Last` order.

Only the first comma matters. `Public, John Q.` splits into `Public` and
`John Q.`, giving `John Q. Public`.

## Examples

    [filter name]Doe, John[/filter]

produces:

    John Doe

A value that is already in first-last order passes through untouched:

    [filter name]John Doe[/filter]

produces:

    John Doe

Chain with [namecase](namecase.md) to fix all-caps input. The `name`
filter reorders first, then `namecase` normalizes capitalization:

    [filter op="name namecase"]DOE, John[/filter]

The `name` step yields `John DOE`, which `namecase` then case-folds.

## See also

[namecase](namecase.md), [lcfirst](lcfirst.md), [ucfirst](ucfirst.md)

## Source

Defined in `code/Filter/name.filter`.
