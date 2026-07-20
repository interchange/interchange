# exists

Checks that a field's value is the key of an existing record in a database
table, or -- with a column name -- that it matches some value already
present in a specific column.

## Syntax

    FIELD=exists TABLE[:COLUMN] [message]

Used as the check name in an order-profile line. There is no shipped strap
demo profile using `exists` directly, but the sibling check
[unique](unique.md) (the same lookup, inverted) is used in
`pages/member/change_email.html`:

    email=unique userdb::usernick Sorry, that email is already associated with an account.

`exists` takes the identical argument form, checking that a value is present
rather than absent, e.g.:

    sku=exists products Product not found in database.

## Description

The check argument names a table (`TABLE`) and, optionally after one or more
colons, a column (`COLUMN`); everything after that is the failure `message`.

- With no `COLUMN`, the check succeeds if `FIELD`'s value is an existing
  primary key in `TABLE` (`$db->record_exists($value)`).
- With `COLUMN`, the check succeeds if some row in `TABLE` has that value in
  `COLUMN` (`$db->foreign($value, $column)`) -- a foreign-key style lookup.

If `TABLE` doesn't exist as a configured database, the check fails with
`Table TABLE doesn't exist` regardless of the value. If no custom `message`
is given, the failure text is `Key VALUE does not exist in TABLE, try
again.`.

## Examples

Require that a submitted SKU is a real row in `products`:

    sku=exists products

Same check with a custom error message:

    sku=exists products Product not found in database.

Look the value up in a non-key column instead of the primary key -- confirm
a submitted state code exists in the `state` table's `state` column:

    ship_state=exists state:state Not a recognized state.

## See also

[unique](unique.md), [error](../tags/error.md),
[Databases guide](../guides/databases.md),
the [cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Defined in `code/OrderCheck/exists.oc`. The routine takes
`($ref, $name, $value, $code)`, resolves the table with
`database_exists_ref` (`lib/Vend/Data.pm`), and calls `record_exists` or
`foreign` (`lib/Vend/Table/Common.pm`) on the resulting table object.
