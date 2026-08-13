# Mall

Scopes session cookies to the current catalog's URL path instead of the whole
domain. Reach for it when several catalogs share one domain and must not
overwrite each other's session cookie.

**Scope:** global (`interchange.cfg`)

## Syntax

    Mall  yes|no

A boolean (`parse_yesno`): `yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`.
Default: `No`.

## Description

When Interchange sends a session cookie it normally issues it for the whole
base domain, so any catalog on that domain sees the same cookie. When `Mall`
is enabled and no explicit [CookieDomain](CookieDomain.md) is set, the cookie
is issued with a `path` restricted to the catalog's own script path (plus any
catalog aliases) rather than domain-wide. This lets multiple catalogs run on
the same domain without clobbering one another's session ID.

The relevant logic is in the cookie-writing code of `lib/Vend/Server.pm`: if
[CookieDomain](CookieDomain.md) is set it wins; otherwise, if `$Global::Mall`
is true, the cookie paths are taken from the current catalog's `script` (and
`alias` list). With [FullUrl](FullUrl.md) also enabled, the leading host
portion is stripped from each script path first.

`Mall` is a global setting evaluated at startup and applied to every
cookie-issuing response.

## Examples

Issue cookies only for the current catalog, not the whole domain (as shipped
commented-in the distributed `interchange.cfg`):

```
Mall  Yes
```

## Notes

[CookieDomain](CookieDomain.md) takes precedence: if you set an explicit
cookie domain, `Mall` has no effect on the path. `Mall` addresses path
scoping, not domain scoping.

## See also

[CookieDomain](CookieDomain.md), [Cookies](Cookies.md),
[CookieName](CookieName.md), [CookieLogin](CookieLogin.md),
[FullUrl](FullUrl.md), the [sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via `$Global::Mall`
in the cookie-writing code of `lib/Vend/Server.pm`.
