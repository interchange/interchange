# filter_select

Chooses an appropriate value-storage filter automatically based on the HTML
widget type that submitted the value; used internally by the survey/form
machinery.

## Syntax

    [value name=field filter="filter_select"]
    [filter filter_select]TEXT[/filter]

`calculated` is an alias for this filter; see
[calculated](calculated.md).

## Description

This is a *meta-filter*: instead of transforming the value, it inspects the CGI
`type` variable (the widget type that produced the field) and returns the
*name* of the filter that should actually be applied to that widget's value.
The mapping is:

| Widget type contains | Filter name returned            |
|----------------------|---------------------------------|
| `fillin`             | `nullselect`                    |
| `select` and `multip`| `null_to_comma`                 |
| `checkbox`           | `checkbox null_to_comma`        |
| anything else        | (empty string — no filter)      |

The returned name is then run against the value by the surrounding form/store
code, so a multi-select's null-joined values become comma-joined, a checkbox's
value is normalized, and so on. The filter is marked `Visibility private`: it
is a building block for Interchange's form-storage and survey handling rather
than something you normally place by hand in a page.

You *can* list `filter_select` alongside your own filters in the same filter
specification; it contributes whichever filter its widget-type test selects,
and your filters run in sequence with it.

Because the choice depends on the live CGI `type` value, output is not
deterministic in isolation and no literal output is shown here.

## Examples

Applied to a survey field whose widget was a multi-select, so its value arrives
as a null-joined list:

    [value name=interests filter="filter_select"]

With `type=select-multiple`, `filter_select` resolves to
[null_to_comma](null_to_comma.md), turning the null-joined selections into a
comma-separated list before storage.

## See also

- [calculated](calculated.md)
- [nullselect](nullselect.md)
- [null_to_comma](null_to_comma.md)
- [checkbox](checkbox.md)

## Source

Defined in `code/Filter/filter_select.filter` (which also declares the alias
`calculated`).
