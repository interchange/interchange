# FallbackIP

Gives a cookieless visitor a session anyway, by deriving the session ID from
their IP address and browser. Reach for it when you need some continuity for
clients that refuse cookies, accepting that the identifier is weaker than a
real cookie-backed session.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    FallbackIP  yes|no

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`). Default: `No`.

## Description

Interchange normally tracks a visitor with a session ID carried in a cookie or
in the URL. When a request arrives with neither -- for example a client that
rejects cookies and follows a bare link -- there is ordinarily no session to
attach to.

With `FallbackIP` enabled, Interchange manufactures a session ID from the
remote IP address combined with the user agent string when no other session ID
is present. Two requests from the same address and browser therefore land on
the same session, giving a rough form of continuity without a cookie.

The identifier is only as stable and as unique as the IP/user-agent pair it is
built from: visitors behind a shared proxy or NAT can collide onto one session,
and a visitor whose address changes loses theirs. Treat it as a best-effort
fallback, not as authentication.

## Examples

Enable IP-based fallback sessions in `catalog.cfg`:

```
FallbackIP  Yes
```

## Notes

Because several clients can share one address, do not rely on a `FallbackIP`
session to hold private or security-sensitive data. It is meant to smooth
navigation for cookieless clients, not to identify a specific person.

## See also

[Cookies](Cookies.md), [CookieName](CookieName.md),
[WideOpen](WideOpen.md), the [sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Dispatch.pm` (session ID assignment), which builds the fallback ID
with `generate_key($CGI::remote_addr . $CGI::useragent)`.
