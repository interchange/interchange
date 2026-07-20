# always_fail

An order check that always fails, regardless of the field's value -- useful
for unconditionally rejecting a submission unless some other logic clears the
field first.

## Syntax

    FIELD=always_fail [message]

Used as the check name in an order-profile line, for example in
`include/profiles/`:

    expired=always_fail That link was expired. Please try ordering again.

## Description

The check ignores the value of `FIELD` entirely and always reports failure.
If a `message` is given, it becomes the [error](../tags/error.md) text stored
for the field; otherwise the default message `failed` is used.

`always_fail` is typically wired up behind a conditional so it only runs when
you already know the submission must be rejected -- for example, guarding a
page against a stale bookmarked link. The strap demo's `check_opt` profile
does exactly this:

    [either]
    [scratch check_opt]
    [or]
    expired=always_fail That link was expired. Please try ordering again.
    [/either]

Here `expired` is not a real form field; the check only runs (and only fails)
when the `[either]`/`[or]` block falls through to the `[or]` branch, i.e. when
the `check_opt` scratch value is not set.

## Examples

Reject a hidden honeypot field outright if it is ever present:

    honeypot=always_fail Bot submission detected.

Reached only from the strap demo's `check_opt` order profile
(`include/profiles/profiles.order`), guarding an expired link:

    [either]
    [scratch check_opt]
    [or]
    expired=always_fail That link was expired. Please try ordering again.
    [/either]

## See also

[always_pass](always_pass.md), [error](../tags/error.md),
[OrderProfile](../config/OrderProfile.md),
the [cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Defined in `code/OrderCheck/always_fail.oc`. The routine takes
`($ref, $name, $value, $msg)` and always returns `(0, $name, $msg ||
errmsg('failed'))`.
