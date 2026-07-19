# SuppressCachedCookies

When enabled, stops Interchange from sending session cookies (and from writing
the session) on pages that are marked cacheable, so a cached page behaves the
same whether it is served from cache or freshly generated.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SuppressCachedCookies  yes|no

Boolean (parser type `yesno`): `yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`.
Default: `no`.

## Description

A page is treated as cacheable when its response carries a `Cache-Control`
header (via the [cache_control](../pragmas/cache_control.md) pragma or an
explicit status line) that is not `no-cache`. Because a visitor who receives
such a page from an upstream cache would not have their session touched,
`SuppressCachedCookies` makes Interchange enforce the same outcome for the
visitor who triggers the fresh generation: no cookie is set and the session is
not written for that request.

`POST` requests are never suppressed -- they are always allowed to set cookies
and write the session. Enable this only for catalogs whose cacheable pages are
written to tolerate the absence of a per-visitor session.

## Examples

Suppress cookies on cacheable pages for this catalog:

```
SuppressCachedCookies yes
```

## See also

[Cookies](Cookies.md), [CookieName](CookieName.md),
[OutputCookieHook](OutputCookieHook.md),
[cache_control](../pragmas/cache_control.md), the
[performance](../guides/performance.md) and [sessions](../guides/sessions.md)
guides.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm` (stored in
`$Vend::Cfg->{SuppressCachedCookies}`); consumed in `lib/Vend/Server.pm`, where
it gates `$Vend::suppress_cookies`.
