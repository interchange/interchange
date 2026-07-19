# userdb

Run a user-database operation: log a customer in or out, create an account,
save or restore their account fields, and save, restore, or list their carts,
shipping addresses, billing addresses, and preferences. This tag is the page-
level front door to Interchange's UserDB subsystem.

## Syntax

    [userdb FUNCTION]
    [userdb function=FUNCTION attr=value ...]

Standalone tag (no end tag). It returns a success/failure status (or a message
string when asked), and sets `$Session->{success}` or `$Session->{failure}` as
a side effect. Session data is the per-visitor store Interchange keeps across
requests.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `function` | required | The operation to perform (see below). |
| `profile` | `default` | Which `UserDB` directive profile governs table, columns, and behavior. |
| `nickname` | none | Name of the saved cart / address / preference set to act on. Alias: `nick`, `name`. |
| `username` | current user | The account to operate on (used by `login`, `new_account`, admin operations). |
| `password` | none | Password, for `login` and `new_account`. |
| `show_message` | `0` | Return the subsystem's message text instead of a 1/0 status. |
| `hide` | `0` | Suppress the return value entirely (side effects still happen). |

Positional order: `function` (the single positional argument). The tag accepts
arbitrary named attributes (`addAttr`), which are passed to the UserDB method;
`table` is an alias for `db`, and `name` is an alias for `nickname`. Which
extra attributes matter depends on the function.

## Description

`function` selects a UserDB operation. The core functions are handled
explicitly; any other value is dispatched as a method call on the UserDB
object, which is how the address-book and cart operations below are reached.

Account and session:

- `login` — authenticate `username`/`password` and mark the session logged in.
- `logout` — log the current user out. Common companions clear session state:
  `clear=1` resets values and scratch set up by UserDB, `clear_session=1`
  starts a brand-new session, and `clear_cookie="MV_PASSWORD"` expires the
  named cookie.
- `new_account` — create an account; logs in automatically unless
  `no_login=1`.
- `save` (alias `set_values`) — write the current form [value](value.md)s back
  to the logged-in user's row.
- `load` (alias `get_values`) — read the user's row into the values (and
  optionally scratch) namespace.
- `change_pass` — change the logged-in user's password.

Saved carts, addresses, and preferences (each keyed by `nickname`):

- `set_cart` / `get_cart` / `get_cart_names` / `delete_cart`
- `set_shipping` / `get_shipping` / `get_shipping_names` / `delete_shipping`
- `set_billing` / `get_billing` / `get_billing_names` / `delete_billing`
- `set_preferences` / `get_preferences` / `get_preferences_names`

All functions except `login`, `logout`, and `new_account` require an already
logged-in session; called otherwise they set `$Session->{failure}` to "Not
logged in." and return undefined.

The tag's full behavior — table layout, the `UserDB` directive, password
encryption, access control, and the values it populates — is covered in the
[user-database guide](../guides/user-database.md). This page documents the tag
interface; see the guide for the subsystem.

## Examples

A minimal login form posts a username and password and calls `login` on the
action page:

    [userdb function=login]

Log out and wipe the UserDB-managed values and scratch in one call:

    [userdb function=logout clear=1]

Save the current cart under a nickname the customer chose, then list their
saved carts:

    [userdb function=set_cart nickname=basket]
    [loop list="[userdb function=get_cart_names]"] [loop-code]<br>[/loop]

Restore a saved cart:

    [userdb function=get_cart nickname=basket]

Return the subsystem's message (for display) instead of a status flag:

    [userdb function=login show_message=1]

## Notes

The return value is a status flag by default; pass `show_message=1` to get the
human-readable success or error message, or `hide=1` to keep the side effect
but emit nothing. When a call fails, the reason is in `$Session->{failure}`,
which is what error-display components typically show.

## See also

- [User-database guide](../guides/user-database.md)
- [value](value.md) — the namespace `save`/`load` read and write
- [UserDB](../config/UserDB.md) — the directive that defines profiles
- [Cart and checkout guide](../guides/cart-and-checkout.md)

## Source

Defined in `code/SystemTag/userdb.coretag` (registered name `userdb`).
Implemented by `Vend::UserDB::userdb`, which constructs a `Vend::UserDB` (or
`Vend::UserControl`) object and calls the matching method.
