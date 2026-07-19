# read-cookie

Return the value of a browser cookie by name. Use it to read a cookie your
catalog (or another application on the same domain) previously set with
[set-cookie](set-cookie.md).

## Syntax

    [read-cookie name]
    [read-cookie cookiename]

Standalone tag (no end tag). Returns the cookie's decoded value, or nothing if
the cookie is not present.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | none    | Name of the cookie to read (positional). |

Positional order: `name`.

## Description

The tag reads the request's `Cookie:` header (Interchange's `$CGI::cookie`
string), finds the first entry matching `name` case-insensitively, and returns
its value after URL-unescaping it. If the named cookie is not in the header the
tag returns an empty result.

Cookies read here are the ones the browser sent with the current request. A
cookie set during this same request with [set-cookie](set-cookie.md) is not
visible to `[read-cookie]` until the browser sends it back on the next request.

## Examples

Read a cookie named `mylogin`:

    [read-cookie mylogin]

Use it inside a conditional to greet a returning visitor:

    [if type=explicit compare="[read-cookie seen_before]"]
    Welcome back!
    [else]
    [set-cookie name=seen_before value=1]
    Welcome, first-time visitor.
    [/else]
    [/if]

## Notes

Interchange's own session cookie (`MV_SESSION_ID` / `MV*`) and any application
cookies are all readable this way. The value is returned exactly as stored, so
if you encoded structured data into the cookie you must decode it yourself.

## See also

- [set-cookie](set-cookie.md)
- Concepts: [sessions](../guides/sessions.md)

## Source

Defined in `code/SystemTag/read_cookie.coretag`. Implemented by
`Vend::Util::read_cookie`.
