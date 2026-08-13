# unique

Checks that a field's value does *not* already exist in a database table --
the inverse of [exists](exists.md), used to enforce that a new record's key
(or a column such as an email address) isn't already taken.

## Syntax

    FIELD=unique TABLE[:COLUMN] [message]

Used as the check name in an order-profile line. The strap demo's account
page (`pages/member/change_email.html`) uses it, chained after
[email_only](email_only.md), to make sure a new email address isn't already
registered:

    email=email_only Please enter a valid email address.
    &and
    email=unique userdb::usernick Sorry, that email is already associated with an account.

## Description

The argument names a table (`TABLE`) and, optionally after one or more
colons, a column (`COLUMN`); everything after that is the failure `message`.

- With no `COLUMN`, the check succeeds if `FIELD`'s value is *not* an
  existing primary key in `TABLE` (`$db->record_exists($value)`).
- With `COLUMN`, the check succeeds if *no* row in `TABLE` has that value in
  `COLUMN` (`$db->foreign($value, $column)`).

If `TABLE` doesn't exist as a configured database, the check fails (rather
than passing) with `Table TABLE doesn't exist`. If no custom `message` is
given, the failure text is `Key VALUE already exists in TABLE, try again.`.

## Examples

Ensure a new username isn't already in `userdb`:

    username=unique userdb

Ensure an email address isn't already registered under a different column,
as the strap demo does (note the double colon separating table and column):

    email=email_only Please enter a valid email address.
    &and
    email=unique userdb::usernick Sorry, that email is already associated with an account.

## Notes

This check only guarantees that the value was unused at the moment it ran;
there is a small window between the check and the record actually being
created (or the transaction committing) during which a concurrent
submission could claim the same value. Pair it with a database-level
uniqueness constraint if that race matters for your data.

## See also

[exists](exists.md), [email_only](email_only.md), [error](../tags/error.md),
[OrderProfile](../config/OrderProfile.md),
the [cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Defined in `code/OrderCheck/unique.oc`. The routine takes
`($ref, $name, $value, $code)`, resolves the table with
`database_exists_ref` (`lib/Vend/Data.pm`), and inverts the result of
`record_exists` or `foreign` (`lib/Vend/Table/Common.pm`).
