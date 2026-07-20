# allow_for_users

Extends the [adjust_href](adjust_href.md) link rewriting so that links a user
sends or resends — links that already carry an Interchange URL prefix or query
string — are re-adjusted rather than left as-is. Set it together with
`adjust_href` when you want previously-generated links to be re-processed.

**Default:** off — already-adjusted links are not stripped and re-adjusted.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma allow_for_users

Page-wide, anywhere in an Interchange page:

    [pragma allow_for_users]
    [pragma allow_for_users 0]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma allow_for_users]1[/tag]

This is a boolean pragma.

## Description

This pragma is consulted by the [adjust_href](../tags/adjust_href.md) tag,
which does the link rewriting behind the [adjust_href](adjust_href.md) pragma.
When `allow_for_users` is set, the tag:

- strips a leading [VendURL](../config/VendURL.md) prefix from a link's `href`
  before deciding how to adjust it, so an already-built Interchange link is
  reduced back to its page reference and re-adjusted; and
- pulls the existing query string off the `href`, dropping session-specific
  parameters (`mv_pc`, `mv_session_id`, `mv_source`, `id`) and folding the rest
  into the link's form parameters.

Without this pragma, links that were already adjusted (for example, ones a user
downloaded and later resubmitted) are left untouched.

## Examples

Re-adjust user-supplied links. In `catalog.cfg`:

    Pragma adjust_href
    Pragma allow_for_users

## Notes

This pragma has no effect on its own; it only modifies the behavior of the
[adjust_href](../tags/adjust_href.md) tag, which runs when the
[adjust_href](adjust_href.md) pragma is in force.

## See also

- [adjust_href](adjust_href.md) pragma
- [adjust_href](../tags/adjust_href.md) tag
- [VendURL](../config/VendURL.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed by the `adjust_href` tag in
`code/UserTag/adjust_href.tag`.
