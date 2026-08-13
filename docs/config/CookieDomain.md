# CookieDomain

Sets the `domain=` attribute of Interchange's session cookie so that servers
sharing a common domain also share one session. Reach for it when a catalog is
served from more than one hostname (for example a separate SSL host) and you
want a single session across them.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    CookieDomain  domain_name ...

One or more space-separated domain names. Default: empty (the cookie is scoped
to the accessing hostname only).

## Description

By default Interchange sets the session-ID cookie for exactly the hostname the
visitor used, so a visitor moving between `www.example.com` and
`ssl.example.com` would get two separate sessions. `CookieDomain` fixes that by
adding a `domain=` attribute naming the shared part of the fully qualified
domain name (for example `.example.com`), which browsers then send to every
host under that domain.

When multiple domains are listed, a `Set-Cookie` header is emitted for each.
Because of browser cookie restrictions this is rarely needed.

## Examples

Share the session across all hosts under `example.com`, in `catalog.cfg`:

```
CookieDomain .example.com
```

## Notes

Browsers accept a cookie domain only if it contains at least two fields (one
dot), and only if the setting host is that domain or a subdomain of it. A host
can set a cookie for itself or its own domain, but not for an unrelated domain.
Mozilla-family browsers prepend a leading dot even when you omit it, so
`example.com` behaves the same as `.example.com`.

## See also

[CookieName](CookieName.md), [CookieLogin](CookieLogin.md),
[Cookies](Cookies.md), [SaveExpire](SaveExpire.md), the
[sessions](../guides/sessions.md) guide.

## Source

Parsed with no parser (raw string) in `lib/Vend/Config.pm`; consumed when
emitting the session cookie in `lib/Vend/Server.pm`.
