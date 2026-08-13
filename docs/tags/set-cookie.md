# set-cookie

Queue a cookie to be sent to the browser with the current response. Use it to
persist a small value on the client across sessions, such as a remembered
username or a preference flag.

## Syntax

    [set-cookie name value]
    [set-cookie name=NAME value=VALUE expire="30 days" domain=.example.com path=/ secure=1]

Standalone tag (no end tag). Produces no output; its effect is the queued
`Set-Cookie` header.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | (required) | Cookie name. |
| `value`   | (required) | Cookie value. |
| `expire`  | session | Expiration. A relative phrase such as `30 days`, `7 weeks`, or `60 minutes` is converted to an absolute time; otherwise the string is used as given. Omit for a session cookie. |
| `domain`  | none    | Cookie domain scope. |
| `path`    | none    | Cookie path scope. |
| `secure`  | `0`     | When true, mark the cookie so the browser sends it only over HTTPS. |

Positional order: `name`, `value`, `expire`, `domain`, `path`, `secure`.

## Description

`[set-cookie]` maps to `Vend::Util::set_cookie`, which adds the cookie to the
list Interchange emits as `Set-Cookie` headers on the current response. If a
cookie with the same name is already queued, it is replaced, so setting the same
name twice keeps only the last value.

The `expire` value is parsed leniently: a bare number followed by a time unit
(for example `30 days`) is turned into an absolute expiry relative to now.
Anything else is passed through unchanged, and omitting `expire` produces a
session cookie that lasts until the browser closes.

The cookie is only queued, not sent immediately; it goes out with the page's
HTTP headers, so a `[set-cookie]` anywhere on the page takes effect for that
response. To read a cookie back, use [read-cookie](read-cookie.md).

## Examples

Set a session cookie:

    [set-cookie name=seen_banner value=1]

Remember a username for 30 days, scoped to the whole site over HTTPS only:

    [set-cookie
        name=remember_user
        value="[value username]"
        expire="30 days"
        path=/
        secure=1
    ]

## Notes

Interchange already manages its own session cookie; use `[set-cookie]` only for
your own application values, and keep them small.

## See also

- [read-cookie](read-cookie.md)
- Concepts: [sessions](../guides/sessions.md)

## Source

Defined in `code/SystemTag/set_cookie.coretag`. Implemented by
`Vend::Util::set_cookie`.
