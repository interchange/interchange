# Cookies

Controls whether Interchange sends an HTTP session cookie to the browser
and reads it back to track the shopper's session. Reach for it when you
want to turn browser cookies off for a catalog (rare) or confirm they are
on.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Cookies  yes|no

A boolean (`parse_yesno`): `Yes`, `No`, `1`, `0`, `on`, `off`,
`true`, `false`, case-insensitive. Default: `Yes`.

## Description

A session cookie lets Interchange recognize a returning request as part of
the same session without carrying the session ID in the URL. With
`Cookies Yes` (the default) Interchange plants a cookie named after
[CookieName](CookieName.md) whose value is the session ID, and reads it
back on subsequent requests.

The flag is consumed in `lib/Vend/Server.pm`, which decides whether to add
the session cookie to the outgoing response. When set to `No`, no session
cookie is emitted and the session ID must travel some other way (typically
embedded in page URLs).

Cookies underpin several features that need to recognize a returning
browser without a URL-borne session ID: page caching, timed builds, and
static page building do not take effect unless `Cookies` is enabled.

## Examples

Session cookies are on by default, so you only set this directive to turn
them off:

```
Cookies No
```

## Notes

Turning cookies off does not disable all cookie handling: features such as
[CookieLogin](CookieLogin.md) and application code that sets its own
cookies operate independently. This directive governs only the automatic
session cookie.

## See also

[CookieName](CookieName.md), [CookiePattern](CookiePattern.md),
[CookieDomain](CookieDomain.md), [CookieLogin](CookieLogin.md),
[SaveExpire](SaveExpire.md), the [sessions](../guides/sessions.md) guide
and the [glossary](../glossary.md) cookie entry.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{Cookies}` in `lib/Vend/Server.pm`.
