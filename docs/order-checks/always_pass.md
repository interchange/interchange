# always_pass

An order check that always succeeds, regardless of the field's value --
a placeholder for a field position in an order profile that has no real
validation.

## Syntax

    FIELD=always_pass

Used as the check name in an order-profile line. From the strap demo's
shared `COMMON_ORDER_PROFILE` (`catalog.cfg`):

    mv_same_billing=always_pass
    fname=required
    lname=required
    address1=required
    address2=always_pass
    city=required

## Description

The check reads no argument and never fails. It is a way to keep a field
listed in a profile -- so that, for example, tooling that inspects the
profile can see every relevant field name -- without imposing any
requirement on its value. `address2` (an optional second address line) and
`mv_same_billing` (a checkbox that legitimately may be blank) are typical
candidates: both appear in the strap demo's common order profile deliberately
paired with `always_pass` rather than being omitted.

Any text following `always_pass` on the profile line is ignored; the check
never fails, so no error message is ever shown.

## Examples

Mark an optional second address line as present in the profile but never
required, as the strap demo does in `catalog.cfg`:

    address2=always_pass

Document a checkbox field that has no validation of its own:

    mv_same_billing=always_pass

## See also

[always_fail](always_fail.md), [required](required.md),
[OrderProfile](../config/OrderProfile.md),
the [cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Defined in `code/OrderCheck/always_pass.oc`. The routine ignores its
arguments and always returns `(1, $_[1], '')`.
