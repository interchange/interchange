# CookieName

Sets the name of the cookie Interchange reads to recover a visitor's session
ID. Reach for it only when you must interoperate with a session cookie issued
by some program other than Interchange itself.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    CookieName  cookie_name

A single cookie name. Default: `MV_SESSION_ID`.

## Description

Interchange identifies a returning visitor by reading its session-ID cookie,
whose name is `CookieName`. The value Interchange plants normally consists of a
session ID, a colon, and an IP address, username, or domain name.

The default should not be changed for ordinary catalogs. Override it only when
another program generates the session cookie: point `CookieName` at that
cookie's name and Interchange will adopt its value without modifying it.

## Examples

Read the session ID from a cookie named `SESSIONID`, in `catalog.cfg`:

```
CookieName SESSIONID
```

## Notes

The value read from the cookie is validated against
[CookiePattern](CookiePattern.md); a custom cookie's value must match that
pattern to be accepted. If you set `CookieName` but leave
[InternalCookie](InternalCookie.md) off, Interchange trusts the external
cookie's value directly.

## See also

[CookiePattern](CookiePattern.md), [CookieLogin](CookieLogin.md),
[CookieDomain](CookieDomain.md), [Cookies](Cookies.md),
[InternalCookie](InternalCookie.md), the [sessions](../guides/sessions.md)
guide.

## Source

Parsed with no parser (raw string) in `lib/Vend/Config.pm`; consumed during
session lookup in `lib/Vend/Dispatch.pm` and `lib/Vend/Server.pm`.
