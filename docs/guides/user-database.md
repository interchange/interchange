# User accounts (UserDB)

A **UserDB account** is a persistent identity a shopper can log back into:
a row in a database table that remembers their name, addresses, saved
carts, preferences, and an encrypted password. Where a
[session](sessions.md) lasts only as long as the visitor keeps coming
back before it expires, an account survives indefinitely and can be
restored on any later visit with a username and password. This chapter
covers the whole subsystem — the account table, the
[userdb](../tags/userdb.md) tag that drives it, logging in and out,
creating accounts, password hashing and the bcrypt migration path,
resetting forgotten passwords, and the address books, saved carts, and
preference stores that hang off an account.

Accounts sit on top of [forms](forms.md) and [sessions](sessions.md):
a login is an ordinary form submission whose values are checked against
the account table, and a successful login writes a few keys into the
current session. Read those two chapters first if the `mv_*` form fields,
[value](../tags/value.md)/[scratch](../tags/set.md) spaces, or the
`mv_click`/`mv_check` hooks below are unfamiliar — this chapter builds
directly on them.

## The moving parts

Three things make up the account system:

- **A table**, `userdb` by default, with one row per account. Its key
  column is the username; other columns hold the password, timestamps,
  and whatever profile/address data you save. It is an ordinary
  [Database](../config/Database.md) — nothing about it is magic except
  the column names UserDB looks for.
- **The [userdb](../tags/userdb.md) tag**, the single entry point for
  every account operation. You call it with `function=login`,
  `function=new_account`, `function=logout`, and so on. It returns true
  on success and the empty string (with an error stashed in the session)
  on failure.
- **[UserDB](../config/UserDB.md) profiles** in `catalog.cfg`, which set
  the defaults every `userdb` call inherits — which table, which columns,
  which hash algorithm, minimum lengths. The full option table lives on
  the [UserDB](../config/UserDB.md) directive page; this chapter explains
  the options in context rather than repeating the table.

Do not confuse [UserDB](../config/UserDB.md) with
[UserDatabase](../config/UserDatabase.md): the latter names a table for
the old HTTP Basic-auth admin check and is unrelated to the customer
login system described here.

## The account table

Any [Database](../config/Database.md) with the right columns can be a
UserDB table. The strap demo's `userdb` table (`products/userdb.txt`)
begins:

    username  usernick  password  expiration  acl  mod_time
    s_nickname  company  fname  lname  address1 ... b_nickname ...
    p_nickname  email  ...  address_book  accounts  preferences  carts ...

The columns UserDB treats specially (everything else is just a saved
value) and the profile option that renames each:

| Purpose | Default column | Renamed by |
|---------|----------------|-----------|
| username / key | `username` | `user_field` |
| password | `password` | `pass_field` |
| last-login time | `mod_time` | `time_field` |
| account expiration | `expiration` | `expire_field` |
| shipping address book | `address_book` | `addr_field` |
| billing accounts book | `accounts` | `bill_field` |
| preferences | `preferences` | `pref_field` |
| saved carts | `carts` | `cart_field` |
| superuser flag | `super` | `super_field` |
| access-control lists | `acl` / `file_acl` / `db_acl` | `acl` / `file_acl` / `db_acl` |
| group membership | `groups` | `groups_field` |

The special columns are read into fixed places; every *other* column
present in the table is loaded into the matching session
[value](../tags/value.md) at login and written back when you save. So a
`fname` column becomes `[value fname]`, a `phone_day` column becomes
`[value phone_day]`, and adding a column to the table is all it takes to
have UserDB round-trip a new field.

The address-book, accounts, preferences, and carts columns each hold a
serialized Perl hash (multiple named sets in one field), not a plain
value — see [Address books and saved carts](#address-books-and-saved-carts).

## The userdb tag

[userdb](../tags/userdb.md) takes one positional argument, the function,
and any number of named attributes:

    [userdb function=login]
    [userdb function=get_shipping nickname=Dad]
    [userdb function=new_account username_mask="^[A-Z]*[0-9]"]

`table` is an alias for `database` and `name` for `nickname`. Any
[UserDB](../config/UserDB.md) profile option can also be passed inline as
an attribute, overriding the profile default for that one call:

    [userdb function=new_account passminlen=8]

Because a login has to happen *before* the page it protects is chosen,
the tag is almost never written inline in page body. Instead it runs from
an [mv_click or mv_check](forms.md#one-click-many-variables-mv_click-and-mv_check)
block, where it can set the outcome and the next page before the response
is built. The canonical minimal login, straight from the module's own
documentation:

    [set Login]
    mv_todo=return
    mv_nextpage=welcome
    [userdb function=login]
    [/set]

    <form action="[process]" method="post">
      [form-session-id]
      <input type="hidden" name="mv_click" value="Login">
      Username <input name="mv_username">
      Password <input type="password" name="mv_password">
      <input type="submit" value="Log in">
    </form>

Clicking submit fires the `Login` block, which runs `[userdb
function=login]`; on success the shopper lands on `welcome` already
logged in. strap keeps these blocks in a profile file
(`include/profiles/profiles.login`) loaded by
[OrderProfile](../config/OrderProfile.md) rather than inline in `[set]`,
but the mechanism is identical.

## Configuring with UserDB profiles

Each `UserDB` line in `catalog.cfg` adds one option to a named profile;
repeated lines build the profile up. The `default` profile supplies the
options used whenever `userdb` is called without `profile=`. strap's
configuration is a good reference (`catalog.cfg`):

    UserDB  default  crypt          1
    UserDB  default  bcrypt         1
    UserDB  default  promote        1
    UserDB  default  from_plain     1
    UserDB  default  bcrypt_pepper  __BCRYPT_PEPPER__
    UserDB  default  time_field     mod_time
    UserDB  default  expire_field   expiration
    UserDB  default  indirect_login usernick
    UserDB  default  assign_username 1
    UserDB  default  logfile        logs/userdb.log

A second, differently named profile can coexist and is selected with
`profile=` on the tag:

    UserDB  affiliate  user_field  affiliate
    UserDB  affiliate  database    affiliate
    UserDB  affiliate  crypt       0

    [userdb function=login profile=affiliate]

The complete option list — every column-renaming option, the hashing
switches, the length limits — is documented on the
[UserDB](../config/UserDB.md) directive page.

## Logging in

`function=login` reads `mv_username` and `mv_password` (or explicit
`username=`/`password=` attributes), validates them against the table,
and on success:

- sets `$Vend::Session->{username}` (`[data session username]`) and
  `logged_in`, so `[if session logged_in]` becomes true;
- records the login time in the `time_field` column (unless that column
  is set to `none`);
- loads every non-special column of the row into the session
  [values](sessions.md) space.

Before it accepts anything, login enforces the guards configured on the
profile: the username must be at least `userminlen` characters (default
2) and match `validchars` (`[-A-Za-z0-9_@.]` by default), and the
password must be at least `passminlen` characters (default 4). Every
rejection is logged, but the shopper always sees the same generic
"Invalid user name or password." message so a probe cannot distinguish a
bad username from a bad password.

strap's `pages/login.html` wraps this in a real form. Reduced to the
essentials:

    [set emailcheck]
    &fatal=1
    mv_username=email
    [/set]

    <form action="[process secure=1]" method="post">
      [form-session-id]
      <input type="hidden" name="mv_form_profile" value="emailcheck">
      <input type="hidden" name="mv_todo"     value="return">
      <input type="hidden" name="mv_nextpage" value="login">
      <input type="radio" name="mv_click" value="Login" checked> I have a password
      <input type="email"    name="mv_username" value="[read-cookie MV_USERNAME]">
      <input type="password" name="mv_password">
      <input type="submit" value="Log In">
    </form>

The [mv_form_profile](forms.md#validating-a-submission-profiles)
`emailcheck` gates the submission (the address must look like an email);
`mv_click=Login` then runs the `[userdb login]` block. A failed login
leaves an error in `$Session->{failure}`, which the page prints and
deletes:

    [if session failure]
      <div class="error">[calc]delete $Session->{failure}[/calc]</div>
    [/if]

`[if session logged_in]` is how every other page tells whether someone is
signed in; there is no separate "current user" object to consult from a
page.

## Creating accounts

`function=new_account` reads `mv_username`, `mv_password`, and
`mv_verify`, checks that the two passwords match and clears the length
limits, refuses a username that already exists, writes the row, and — unless
you pass `no_login=1` — logs the new account straight in. strap's
`pages/new_account.html`, trimmed:

    [set NewAccount]
    [if type=explicit compare="[userdb new_account]"]
    mv_nextpage=member/account
    [else]
    mv_nextpage=new_account
    [/else]
    [/if]
    [/set]

    <form action="[process]" method="post">
      [form-session-id]
      <input type="hidden" name="mv_click" value="NewAccount">
      <input type="hidden" name="mv_doit"  value="return">
      Email    <input name="mv_username">
      Password <input type="password" name="mv_password">
      Verify   <input type="password" name="mv_verify">
      <input type="submit" value="Create Account">
    </form>

Options that shape account creation, all set on the profile or passed
inline:

- **`username_mask`** — a Perl regular expression (no surrounding
  slashes); any username matching it is rejected. Use it to keep, say,
  order-number-shaped strings out of the username space:
  `username_mask="^[A-Z]*[0-9]"`.
- **`username_email`** — require the username to be a valid email
  address, and copy it into the `email` column (or
  `username_email_field`) automatically.
- **`assign_username`** — ignore the submitted username and assign a
  sequential one from a counter instead (see below).
- **`captcha=1`** — require a correct [captcha](../tags/captcha.md) code,
  checked before the row is written.
- **`created_date_iso` / `created_date_epoch`** — name a column to stamp
  with the account's creation time.

### Assigned usernames

With `assign_username`, `new_account` pulls the next value from a counter
file (`etc/username.counter` under the catalog by default, or the file
named by `counter=`) and uses that as the table key. The counter's start
value is `U00000`, so assigned keys look like `U00001`, `U00002`, and so
on. The username the shopper actually typed is kept separately — this is
how strap lets people register and log in with an *email address* while
the table key stays a compact opaque id; see
[Indirect login](#indirect-login-email-as-username).

## Logging out

`function=logout` clears the login keys from the session and returns the
shopper to an anonymous state. Options:

- **`clear=1`** — also erase the account's loaded values from the session
  (otherwise the name, addresses, etc. linger until the session ends).
- **`clear_cookie="MV_USERNAME,MV_PASSWORD"`** — expire named cookies,
  used to forget a "remember me" login.
- **`clear_session=1`** — reinitialize the whole session (a hard reset).

strap's logout profile:

    [if type=explicit compare="[userdb function=logout clear=1]"]
      mv_nextpage=[either][cgi mv_successpage][or]index[/either]
    [/if]

Logging out is independent of session expiry: the session itself lives on
(empty of login state) until it times out. Login state never outlives the
session — there is no server-side "stay logged in" beyond the optional
cookie described under [Remember-me logins](#remember-me-logins).

## Passwords and encryption

By default UserDB stores a one-way hash of the password, never the
plaintext. The algorithm is chosen by whichever of these profile options
is set, in the order the module prefers them; `crypt=1` (the default
unless the `MV_NO_CRYPT` [Variable](../config/Variable.md) is set) merely
turns hashing on:

| Option | Algorithm | Notes |
|--------|-----------|-------|
| `bcrypt 1` | bcrypt | Strongest; needs `Digest::Bcrypt` and `Crypt::Random`. |
| `sha1 1` | SHA1 | Needs `Digest::SHA`. |
| `md5_salted 1` | salted MD5 | Salt stored with the hash (Zen Cart compatible). |
| `md5 1` | plain MD5 | |
| (crypt on, none set) | Unix `crypt()` | Weak; the fallback. |
| `crypt 0` | none | Plaintext — never use with real user passwords. |

With `crypt 0` the password is stored and compared as typed. The module's
own documentation is blunt about this: unencrypted passwords are never
recommended when shoppers set their own, because people reuse passwords
across sites. Set `crypt 0` only for throwaway lookup "accounts" (an
order-number/zip pair used to display order status, for instance).

### bcrypt and the promote migration

New catalogs should use bcrypt, as strap does:

    UserDB  default  crypt          1
    UserDB  default  bcrypt         1
    UserDB  default  bcrypt_pepper  __BCRYPT_PEPPER__

`bcrypt_pepper` mixes a catalog-wide secret into every hash so that
stealing the database alone is not enough to mount an offline attack;
strap generates a random 32-character pepper at install time into the
`BCRYPT_PEPPER` variable. The bcrypt cost defaults to 13.

The hard problem with changing hash algorithms is the passwords already
in the table. UserDB solves it with **transparent promotion**. With:

    UserDB  default  promote     1
    UserDB  default  from_plain  1

each time a user logs in successfully, if their stored hash is not in the
currently configured algorithm (or is bcrypt at a different cost), UserDB
re-hashes the password they just proved they know and rewrites the column
in the new format. Old `crypt`/MD5/SHA1 hashes upgrade themselves to
bcrypt organically as people sign in; `from_plain 1` additionally
promotes any rows still holding plaintext. No mass reset, no forced
password change. (UserDB recognizes the stored format by the hash's
length and, for bcrypt, its `$2...$` prefix.)

> Make sure the `password` column is wide enough for the new format
> before enabling promotion — a bcrypt hash is 60 characters. A truncated
> write will lock the account out; UserDB logs a specific error naming the
> column and required width.

### Optional plaintext logging

`enclair_db` names a separate table into which the plaintext (or its MD5)
is written on each account/password change, for fraud or duplicate-password
auditing behind a firewall. It is off unless configured and is a
deliberate security trade-off; see the [UserDB](../config/UserDB.md) page
and the module POD for the query-template details.

## Changing a password

`function=change_pass` reads `mv_password_old`, `mv_password`, and
`mv_verify`. It requires the old password to match (so a shopper cannot
change a password they cannot prove they own), checks the new password
against `passminlen` and its verify field, and rewrites the column. strap
drives it from `pages/member/change_password.html` with an `mv_check`:

    <form action="[process secure=1]" method="post">
      [form-session-id]
      <input type="hidden" name="mv_action" value="return">
      <input type="hidden" name="mv_check"  value="Change_password">
      Old      <input type="password" name="mv_password_old">
      New      <input type="password" name="mv_password">
      Verify   <input type="password" name="mv_verify">
      <input type="submit" value="Change password">
    </form>

A superuser (an account whose `super` column is true) may change another
user's password by passing that user's name; ordinary users may only
change their own, and the attempt is logged if they try otherwise.

## Resetting a forgotten password

There is no "email me my password" — the password is hashed and
unrecoverable. Instead strap implements a signed-token reset across three
pages, worth understanding because it is the template for doing this
safely. The tie that binds them is a catalog secret,
`PASSWORD_RESET_CHECK_KEY` (a [Variable](../config/Variable.md); change it
from strap's shipped default).

1. **`pages/lost_password.html`** collects an email address and, via
   `mv_click=finduser`, forwards to the generator page.

2. **`pages/member/get_password.html`** looks the address up
   (`$Db{userdb}->foreign($CGI->{lost_email}, 'usernick')`), then builds
   a token and emails a link. The token is the first 20 characters of an
   HMAC:

       [filter op="hmac_sha1_hex.[var PASSWORD_RESET_CHECK_KEY]"]
         [mod_time][expiration][expires][email]
       [/filter]

   Folding the row's current `mod_time` and `expiration` into the HMAC
   means the link stops working the moment the reset actually happens.
   The emailed link carries three parameters: `u` (the user id), `x` (an
   expiry stamp, one day out), and `k` (the token).

3. **`pages/query/pw_reset.html`** re-derives the HMAC from `u`/`x` and
   the row, and only if it matches `k` (and `x` has not passed) does it
   set a random temporary password, log the user in with it, and present
   a change-password form. On success it clears the expiration so the
   account is fully live again.

The whole exchange never transmits or stores a recoverable password, and
the link is single-use because completing the reset changes the very
fields the token was signed over.

## Loading and saving account values

Login loads the row automatically, but you can also move data between the
table and the session on demand:

- **`function=save`** writes every non-special session
  [value](../tags/value.md) that has a matching column back to the row.
  This is what an "edit my account" form calls.
- **`function=load`** does the reverse — the same load login performs —
  useful to refresh the session from the table without re-authenticating.

Where each column lands is configurable. By default columns become
values; these options redirect them:

- **`scratch "field1 field2"`** — load the named columns into
  [scratch](../tags/set.md) instead of values (for control data you do
  not want the shopper editing on a form). strap uses
  `scratch "dealer price_level credit_limit usernick"`.
- **`constant "..."`** — load into the session `constant` space.
- **`session_hash "..."`** — deserialize a column into a session key.
- **`read_only "..."`** — load these columns but never write them back
  through `save`.

For `load` you can also aim the values somewhere other than `$Values`
with `valref` (and scratch with `scratchref`), either a bare session key
or a Perl reference:

    [userdb function=load valref=user_record]
    [userdb function=load valref=`$Session->{values_repository}{userdb} ||= {}`]

An `extra_fields` option can pack several additional values into a
sub-hash of the preferences column keyed by `extra_selector`, for storing
odds and ends without adding table columns.

## Address books and saved carts

An account can hold *several* named shipping addresses, billing profiles,
preference sets, and shopping carts — each stored as a serialized hash in
its column (`address_book`, `accounts`, `preferences`, `carts`), keyed by
a nickname.

The shipping functions and the fields they move (the `s_nickname` value
selects which entry):

    [userdb function=set_shipping nickname=Dad]   save current s_* values
    [userdb function=get_shipping nickname=Dad]   restore them
    [userdb function=get_shipping_names]          list nicknames into address_book

`get_shipping_names` populates `[value address_book]` (newline-joined
nicknames) so a page can offer a picker; pass `show=1` to have it also
return the list inline. Billing (`set_billing`/`get_billing`, the `b_*`
fields, the `accounts` value) and preferences work the same way. strap's
`pages/member/account.html` shows the everyday pattern — list the saved
nicknames, edit the current address, and save:

    [userdb function=get_billing_names]
    [userdb function=get_shipping_names]

    <form action="[process secure=1]" method="post">
      [form-session-id]
      <input type="hidden" name="mv_todo"  value="return">
      <input type="hidden" name="mv_check" value="Save_database">
      [include include/checkout/shipping_address]
      [include include/checkout/billing_address]
      <button type="submit">Save Account Info</button>
    </form>

where the `Save_database` check block runs `[userdb save]`.

Saved carts use the same nickname model over the `carts` column:

    [userdb function=set_cart nickname=christmas]              save the current cart
    [userdb function=get_cart nickname=christmas]              restore it
    [userdb function=get_cart nickname=christmas target=wish]  restore into a named cart

`get_cart` replaces the current cart by default; `target=` loads into a
different [cart](cart-and-checkout.md) and `merge=1` appends rather than
replaces.

### The address table variant

Setting the [UserControl](../config/UserControl.md) directive swaps in
`Vend::UserControl`, a subclass that keeps shipping and billing addresses
in a *separate* relational `address` table (one row per address, keyed by
username and nickname) instead of a serialized column. The tag functions
are the same; only the storage differs. Use it when addresses need to be
queried or reported on with SQL. The address/username/nickname column
names are configurable (`address_table`, `address_username_field`,
`address_nickname_field`, ...); see
[UserControl](../config/UserControl.md).

## Indirect login (email as username)

Often you want the table key to be a stable opaque id but let shoppers log
in with their email address. `indirect_login` names a *second* column
holding the login handle:

    UserDB  default  indirect_login  usernick
    UserDB  default  assign_username 1

Now `new_account` assigns a `U…` key and stores the submitted email in
`usernick`; at login, `mv_username` is matched against `usernick` and the
real key is looked up. The email can change without disturbing the key or
any foreign references to it. `fallback_login=1` additionally lets the raw
key still be used directly. strap ships exactly this configuration, which
is why its login form is labelled "email" while the table key is `U00001`.

## Access control, groups, and admin

A UserDB row can also carry authorization data, checked by the same tag:

- **`super`** — a true value in the `super_field` column marks a
  superuser (full admin). `promote_admin` can instead elevate an account
  to a scoped admin based on a scratch-loaded field.
- **`groups`** — loaded into `$Vend::groups`/`$Session->{groups}` at
  login for role checks.
- **Simple ACLs** — `set_acl`/`check_acl` store a space-separated list of
  page locations in the `acl` column, gating access to protected pages:

      [if type=explicit compare="[userdb function=check_acl location=cartcfg/editcart]"]
        [page cartcfg/editcart]Edit cart config</a>
      [/if]

- **Complex ACLs** — `set_file_acl`/`check_file_acl` and
  `set_db_acl`/`check_db_acl` store `mode`-bearing entries (`rw`, `w`, …)
  in `file_acl`/`db_acl` for finer file- and table-level control.

These underpin the [admin UI](admin-ui.md); a customer-facing catalog
usually needs only `[if session logged_in]` and perhaps a simple ACL. See
[Security](security.md) for the trust model.

## Remember-me logins

With the [CookieLogin](../config/CookieLogin.md) directive on, a login
form that includes `mv_cookie_password` (or `mv_cookie_username` for just
the name) writes the credentials to the `MV_USERNAME`/`MV_PASSWORD`
cookies, so the shopper is recognized on their next visit without
retyping. [SaveExpire](../config/SaveExpire.md) sets how long the cookie
lasts (strap: 30 days), renewed on each login. strap only shows the
"Remember me" checkbox when the directive is enabled:

    [if config CookieLogin]
      <input type="checkbox" name="mv_cookie_password" value="1"> Remember me
    [/if]

Pass `secure_cookies=1` so the password cookie is only sent over https,
and offer `clear_cookie` on logout for shared terminals.

## Protecting member-only pages

UserDB gives you the login state; enforcing it on a page is up to the
catalog. strap's convention is a page-top flag checked by an autoloaded
block. Any page that sets `members_only` is bounced to the login form if
no one is signed in (`variables/PAGE_INIT`):

    [if scratch members_only]
      [if !session logged_in]
        [set mv_successpage][var MV_PAGE 1][/set]
        [deliver location="[area login]"]
      [/if]
    [/if]

and a protected page simply declares:

    [tmpn members_only]1[/tmpn]

Capturing `mv_successpage` first means the shopper returns to the page
they were reaching for after they log in. This is a catalog pattern, not a
UserDB feature — adapt it, or gate with an ACL, as your store requires.

## Notes and gotchas

- **Defaults that differ from older docs.** Verified against
  `lib/Vend/UserDB.pm` at current head: the default minimum *password*
  length is **4** (not 2), and the default last-login column is
  **`mod_time`** (not `time`). Some historic option tables — including the
  in-repo [UserDB](../config/UserDB.md) table and the module's own POD —
  still show the older values; the code is authoritative. The default
  expiration column is `expiration`.

- **Field lists are package globals.** The shipping/billing/preference
  field lists (`@S_FIELDS`, etc.) are overwritten process-wide when a call
  passes `shipping=`/`billing=`/`preferences=`. In practice you set these
  once on the `default` profile; be aware that passing them on one call
  affects the field set until another call changes it.

- **Password fields are scrubbed.** After any login, account creation, or
  password change, `mv_password`, `mv_verify`, and `mv_password_old` are
  deleted from both the CGI and value spaces, so they are never stored in
  the session or shown by [dump](../tags/dump.md).

- **Login is silent about why it failed.** Every rejection returns the one
  generic message; the specific reason (bad username, short password,
  expired account, illegal characters) is written only to the log named
  by the profile's `logfile`. Check that log when debugging a login that
  "just doesn't work."

- **Post-login hooks.** `postlogin_action` (and `prelogout_action`) name
  macros to run around the login/logout, e.g. to seed a cart or clear
  scratch.

## See also

- [Forms and user input](forms.md) — the `mv_*` fields, profiles, and the
  `mv_click`/`mv_check` hooks every account form is built from
- [Sessions](sessions.md) — where login state and loaded values live
- [Cart and checkout](cart-and-checkout.md) — saved carts and the address
  data reused at checkout
- [Security](security.md) — the trust model behind ACLs and admin
- Reference: [userdb](../tags/userdb.md) tag,
  [UserDB](../config/UserDB.md), [UserControl](../config/UserControl.md),
  [UserDatabase](../config/UserDatabase.md),
  [CookieLogin](../config/CookieLogin.md),
  [SaveExpire](../config/SaveExpire.md)

## Source

`lib/Vend/UserDB.pm` (the `userdb` dispatcher and every account function),
`lib/Vend/UserControl.pm` (the external-address-table subclass, enabled by
[UserControl](../config/UserControl.md)), and the tag definition
`code/SystemTag/userdb.coretag` (MapRoutine `Vend::UserDB::userdb`). The
reset-token and member-page patterns are strap's
(`dist/strap/pages/lost_password.html`, `pages/member/get_password.html`,
`pages/query/pw_reset.html`, `include/profiles/profiles.login`,
`variables/PAGE_INIT`).
