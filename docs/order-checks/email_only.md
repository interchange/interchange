# email_only

Checks that a field's value is a syntactically valid email address.

## Syntax

    FIELD=email_only [message]

Used as the check name in an order-profile line, or directly in a page's
inline profile. The strap demo uses it several times, for example in
`pages/new_account.html`:

    mv_username=email_only

and conditionally in `catalog.cfg`'s common order profile:

    [if !session logged_in]email=email_only[/if]

## Description

The value passes if it matches the pattern
`[\040-\053\055-\077\101-\176]+\@[-A-Za-z0-9.]+\.[A-Za-z]+` -- one or more
"local part" characters (a printable-ASCII range that excludes whitespace,
comma, and a few punctuation marks), an `@`, a domain made of letters,
digits, dots, and hyphens, and a final all-letter top-level segment. A blank
value fails.

This is a syntax check only; it does not verify that the address exists or
that a mail server accepts it. If no `message` is given, the failure text is
`'VALUE' not an email address`.

## Examples

Require a syntactically valid email as a username, as in the strap demo's
account-creation page:

    mv_username=email_only

Validate an email field with a custom message:

    email=email_only Please enter a valid email address.

Combine with [unique](unique.md) to also require the address isn't already
registered, as `pages/member/change_email.html` does:

    email=email_only Please enter a valid email address.
    &and
    email=unique userdb::usernick Sorry, that email is already associated with an account.

## Notes

A separate, built-in check named `email` (implemented as `_email` in
`lib/Vend/Order.pm`, not a `CodeDef OrderCheck`) uses nearly the same
pattern. `email_only` is the one you get from a `CodeDef`-registered order
check and the one that appears in `code/OrderCheck/`; either name works as a
profile check type, but only `email_only` is documented on this page.

## See also

[unique](unique.md), [match](match.md), [error](../tags/error.md),
[OrderProfile](../config/OrderProfile.md),
the [cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Defined in `code/OrderCheck/email_only.oc`. The routine takes
`($ref, $var, $val, $msg)` and returns `(1, $var, '')` on match, or
`(undef, $var, $msg || errmsg("'%s' not an email address", $val))`.
