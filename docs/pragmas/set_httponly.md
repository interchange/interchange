# set_httponly

Adds the `HttpOnly` attribute to cookies that Interchange sends, for all cookies
or a named subset. Set it to keep cookies (notably the session cookie) out of
reach of client-side JavaScript.

**Default:** off — cookies are sent without `HttpOnly`.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma set_httponly
    Pragma set_httponly=MV_SESSION_ID
    Pragma set_httponly=MV_SESSION_ID;cart

Page-wide, anywhere in an Interchange page:

    [pragma set_httponly]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma set_httponly]MV_SESSION_ID[/tag]

The value is either `1` (or empty, meaning all cookies) or a `;`- or
`,`-separated list of cookie names.

## Description

When Interchange builds `Set-Cookie` headers in `create_cookie()`, it consults
`set_httponly`:

- A value of `1` (or the bare `Pragma set_httponly`) marks **every** cookie
  `HttpOnly`.
- A value that is a list of cookie names marks only those named cookies
  `HttpOnly`. Names may be separated by `;` or `,`; whitespace is stripped.

An `HttpOnly` cookie is not exposed to `document.cookie` in the browser, which
reduces the impact of cross-site scripting on session hijacking.

## Examples

Mark all cookies `HttpOnly`. In `catalog.cfg`:

    Pragma set_httponly

Mark only the session cookie:

    Pragma set_httponly=MV_SESSION_ID

Mark the session cookie plus a custom `cart` cookie:

    Pragma set_httponly=MV_SESSION_ID;cart

## Notes

The per-cookie selection form was added in Interchange 5.12; the original
all-cookies behavior (`Pragma set_httponly`) still works. The default session
cookie name is `MV_SESSION_ID` unless changed by
[CookieName](../config/CookieName.md).

## See also

- [set_samesite](set_samesite.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `create_cookie()` in
`lib/Vend/Server.pm`.
