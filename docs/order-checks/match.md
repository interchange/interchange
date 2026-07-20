# match

Checks that a field's value is identical to the current value of another
named CGI/form variable -- the standard way to implement a "confirm your
password" or "confirm your email" pair of fields.

## Syntax

    FIELD=match OTHERFIELD [message]

Used as the check name in an order-profile line. The strap demo's
password-reset page (`pages/query/pw_reset.html`) uses it to confirm a new
password:

    password_verify=match password The specified passwords do not match.

and its account page (`pages/member/change_email.html`) uses it to confirm a
changed email address:

    email=match email_verify Emails must match.

## Description

The check reads `OTHERFIELD` as the first word of its argument and treats
the rest as the failure `message`. It compares the submitted values
(`$ref->{OTHERFIELD}` against the current field's value) with `ne` --
an exact, case-sensitive string comparison. If no custom `message` is
given, the failure text is `FIELD doesn't match OTHERFIELD.`.

## Examples

Confirm a new password against its verification field:

    mv_verify=match mv_password The passwords must match.

Confirm a changed email address, as the strap demo does:

    email=match email_verify Emails must match.

## See also

[email_only](email_only.md), [required](required.md),
[error](../tags/error.md), [OrderProfile](../config/OrderProfile.md),
the [cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Defined in `code/OrderCheck/match.oc`. The routine takes
`($ref, $name, $value, $msg)`, extracts `OTHERFIELD` from the front of
`$msg`, and compares `$ref->{$other}` to `$value` with `ne`.
