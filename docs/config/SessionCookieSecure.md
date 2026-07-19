# SessionCookieSecure

Controls whether Interchange marks the session-ID cookie as `secure` when the
current request arrived over HTTPS. Reach for it to keep the session cookie from
being sent back over plain HTTP.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SessionCookieSecure  yes|no

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default: `no`.

## Description

When enabled, the session cookie Interchange sets (normally `MV_SESSION_ID`)
gets the `secure` attribute whenever the request came in over a secure
connection. A browser will then only return that cookie over HTTPS, so the
session identifier is not exposed on subsequent plain-HTTP requests.

When disabled (the default), the cookie carries no `secure` flag and is sent on
both HTTP and HTTPS requests.

The flag is applied per response based on whether the current request was
secure, so a visitor who is on HTTPS gets a secured cookie while one on HTTP
does not.

## Examples

Mark the session cookie secure on HTTPS requests:

```
SessionCookieSecure  yes
```

## Notes

Enable this only when your secure and insecure entry points share the same
session; if a visitor moves from an HTTPS page to an HTTP page, a secure-marked
cookie will not be sent, which can start a fresh session.

## See also

[Cookies](Cookies.md), [CookieName](CookieName.md),
[CookieDomain](CookieDomain.md), [SecureURL](SecureURL.md),
[AlwaysSecure](AlwaysSecure.md), the [sessions](../guides/sessions.md) and
[security](../guides/security.md) guides.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`. Consumed in
`lib/Vend/Server.pm` (`create_cookie`), where it sets the cookie's `secure`
attribute from `$CGI::secure`.
