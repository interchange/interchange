# require_order_profile

Makes order submission fail when no order profile is named. By default a submit
with no `mv_order_profile` passes the order-check stage; set this pragma to
require that an order profile be specified.

**Default:** off — a submit without `mv_order_profile` is treated as passing the
check stage.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma require_order_profile

Page-wide, anywhere in an Interchange page:

    [pragma require_order_profile]
    [pragma require_order_profile 0]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma require_order_profile]1[/tag]

This is a boolean pragma.

## Description

When the `submit` form action processes an order, it runs the order profile named
by `mv_order_profile`. If that CGI value is not set, the behavior depends on this
pragma:

- **off (default):** the check stage is treated as passed
  (`$status = $final = 1`), and processing continues.
- **on:** the check stage fails with a "Missing profile" error
  (`$status = undef`, `$final = 0`), so the order does not proceed.

Use it to guarantee that every order goes through an explicit
[OrderProfile](../config/OrderProfile.md), rather than silently succeeding when a
form forgets to set `mv_order_profile`.

## Examples

Require an order profile on every submit. In `catalog.cfg`:

    Pragma require_order_profile

## Notes

This only affects submits where `mv_order_profile` is absent; when a profile is
named, that profile's own checks apply as usual.

## See also

- [OrderProfile](../config/OrderProfile.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed by the `submit` handler in the
`%form_action` dispatch table in `lib/Vend/Dispatch.pm`.
