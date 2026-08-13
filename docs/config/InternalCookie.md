# InternalCookie

Controls whether Interchange keeps managing its own IP-address cookie when
a custom [CookieName](CookieName.md) is in use. Reach for it when you set a
custom cookie name but still want Interchange's internal IP-in-cookie
handling to run.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    InternalCookie  yes|no

Boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default: `No`.

## Description

Interchange can store the client IP address in a cookie to help qualify
sessions. When you define a custom [CookieName](CookieName.md), the
dispatcher normally treats cookie handling as externally managed and steps
back from its internal IP-cookie logic.

Setting `InternalCookie` to `Yes` tells Interchange to continue its
internal IP-in-cookie handling even though `CookieName` has been changed --
letting you rename the cookie while keeping the built-in behavior. With the
default `No`, a custom `CookieName` together with an incoming cookie causes
the dispatcher to defer to the external cookie rather than run its own IP
handling.

The directive is read at catalog configuration time.

## Examples

Rename the cookie but keep internal IP handling (put in `catalog.cfg`):

```
CookieName MYSHOP
InternalCookie Yes
```

## Notes

`InternalCookie` matters only when a non-default `CookieName` is set; with
the stock cookie name it has no observable effect.

## See also

[CookieName](CookieName.md), [Cookies](Cookies.md),
[CookieDomain](CookieDomain.md), [CookieLogin](CookieLogin.md), the
[sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in the cookie
handling of `lib/Vend/Dispatch.pm`.
