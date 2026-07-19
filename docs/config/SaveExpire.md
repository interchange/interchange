# SaveExpire

Sets how long Interchange's persistent cookies -- those other than the
session-ID cookie -- remain valid. Reach for it to control how long a
returning customer's saved login is remembered.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SaveExpire  INTERVAL

A time interval (`parse_time`) such as `30 days`, `52 weeks`, or `12 hours`,
converted to a number of seconds. Default: `30 days`.

## Description

`SaveExpire` sets the expiration time written on the persistent cookies
Interchange issues. It does not affect the session-ID cookie
(`MV_SESSION_ID`), which always lasts only for the duration of the session.
It governs the longer-lived cookies -- notably `MV_USERNAME` and
`MV_PASSWORD`, used by the [CookieLogin](CookieLogin.md) feature so a
customer stays recognized across visits.

The value (in seconds) is consumed in `lib/Vend/Session.pm` when setting a
cookie's expiration and in `lib/Vend/UserDB.pm` when computing the saved
login cookie's lifetime.

## Examples

Remember saved logins for a year (from the historic default style):

```
SaveExpire 52 weeks
```

The strap catalog uses the default interval explicitly:

```
SaveExpire   30 days
```

## Notes

A longer interval keeps customers logged in across more visits but leaves
credential cookies on shared machines longer; balance convenience against
the exposure. The interval accepts the same units as other time directives
(`seconds`, `minutes`, `hours`, `days`, `weeks`).

## See also

[CookieLogin](CookieLogin.md), [SessionExpire](SessionExpire.md),
[Cookies](Cookies.md), [CookieName](CookieName.md), the
[sessions](../guides/sessions.md) and
[user-database](../guides/user-database.md) guides.

## Source

Parsed by `parse_time` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Session.pm` and `lib/Vend/UserDB.pm`.
