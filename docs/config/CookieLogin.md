# CookieLogin

Lets a returning visitor be logged in automatically from credentials saved in a
browser cookie. Reach for it to offer "remember me" auto-login -- but weigh the
security cost first (see Notes).

**Scope:** catalog (`catalog.cfg`)

## Syntax

    CookieLogin  yes|no

A boolean (`yes`/`no`, `1`/`0`). Default: `No`.

## Description

With `CookieLogin` enabled, Interchange can store a user's authentication
information in a cookie and, on a later visit, read it back to log the user in
without a form submission. The cookie's lifetime is governed by
[SaveExpire](SaveExpire.md) and is renewed at each login.

Enabling the directive does not by itself start saving credentials: the cookie
is created only when a request sets `mv_cookie_password` and/or
`mv_cookie_username` to a true value. `mv_cookie_password` saves both username
and password; `mv_cookie_username` saves just the username.

## Examples

Enable cookie-based auto-login in `catalog.cfg`:

```
CookieLogin  Yes
```

The strap demo ships it off, with a warning that it is not secure:

```
CookieLogin  No
```

## Notes

Saving the password in a cookie is not secure -- it stores the credential on
the client. Prefer saving only the username (`mv_cookie_username`) when you use
this feature at all, and be careful about untrusted JavaScript in embedded page
code that could read the cookie.

## See also

[CookieName](CookieName.md), [CookieDomain](CookieDomain.md),
[Cookies](Cookies.md), [SaveExpire](SaveExpire.md),
[UserDB](UserDB.md), the [user-database](../guides/user-database.md) and
[sessions](../guides/sessions.md) guides.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed by the login code in
`lib/Vend/UserDB.pm`.
