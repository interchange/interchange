# some_spec

Checks that a search-specification field holds at least a minimum amount of
actual text -- guards against running an expensive, unconstrained search
from an empty or near-empty search box.

## Syntax

    FIELD=some_spec [minlength]

Used as the check name in an order-profile line. The strap demo's admin
profile file (`include/profiles/profiles.admin`) uses it to guard
`mv_like_spec`, the search specification built by the admin's `flex_select`
table browser:

    __NAME__ some_spec
    ## Used to prevent empty mv_like_spec when present
    ## Useful for flex-select tag that could conceivably do large checks
    &fatal=yes
    &fail=admin/error
    mv_like_spec=some_spec 2

## Description

The field's value is expected to be one or more null-separated (`\0`)
search terms, as `mv_like_spec` and similar multi-column search fields
store them. The check splits on `\0`, sums the length of every term, and
succeeds if that total is at least `minlength` (the check's argument,
default `3`). This tolerates several short terms adding up, rather than
requiring any single term to meet the minimum.

The failure message is fixed -- `Must input some sort of search -- at
least N characters total` -- and does not take a custom-message argument;
the check's only argument is the minimum length.

## Examples

Require the admin's "like spec" search field to hold at least 2 characters
total, exactly as the strap demo's admin profile does:

    mv_like_spec=some_spec 2

Require at least 5 characters, using the default profile name form:

    search_spec=some_spec 5

## Notes

The routine has an early `unless (defined $ref->{$var}) { return (1, $var,
'') if $found >= $len; }` branch intended to pass trivially when the field
is entirely absent from submitted values. In the current code this check
runs before `$found` has been accumulated from the split terms, so
`$found` is still `undef` at that point; the comparison is only ever true
when `$len` itself is `0`. In practice, then, an absent or all-blank
`FIELD` still fails the check rather than passing -- verified by tracing
`code/OrderCheck/some_spec.oc`.

## See also

[flex_select](../admin-tags/flex_select.md), [error](../tags/error.md),
[required](required.md), [OrderProfile](../config/OrderProfile.md),
the [admin UI guide](../guides/admin-ui.md).

## Source

Defined in `code/OrderCheck/some_spec.oc`. The routine takes
`($ref, $var, $val, $len)`, splits `$val` on `\0`, and compares the summed
length of the pieces against `$len` (default `3`).
