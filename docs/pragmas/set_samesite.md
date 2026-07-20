# set_samesite

Adds the `SameSite` attribute to cookies that Interchange sends, either the same
value for all cookies or a per-cookie mapping. Set it to control whether cookies
accompany cross-site requests.

**Default:** off — cookies are sent without a `SameSite` attribute.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma set_samesite=Strict
    Pragma set_samesite=foo=Lax
    Pragma set_samesite=foo=Lax;bar=Strict;baz=None

Page-wide, anywhere in an Interchange page:

    [pragma set_samesite Lax]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma set_samesite]Strict[/tag]

The value is either a single `SameSite` value (`Strict`, `Lax`, or `None`)
applied to all cookies, or a `;`/`,`-separated list of `name=value` pairs.

## Description

When Interchange builds `Set-Cookie` headers in `create_cookie()`, it reads
`set_samesite`:

- A plain value with no `=` (for example `Strict`) is applied as the `SameSite`
  attribute of **every** cookie.
- A value containing `=` is parsed as a set of `name=value` pairs, applying each
  `SameSite` value only to the named cookie. Separators may be `;`, `,`, or `=`;
  whitespace is stripped.

For any cookie whose effective `SameSite` value is `None`, Interchange also forces
the `Secure` attribute on, as browsers require `SameSite=None` cookies to be
secure.

## Examples

Make all cookies `SameSite=Strict`. In `catalog.cfg`:

    Pragma set_samesite=Strict

Set `foo` to `Lax`, `bar` to `Strict`, and `baz` to `None` (which is also forced
`Secure`):

    Pragma set_samesite=foo=Lax;bar=Strict;baz=None

## Notes

Added in Interchange 5.12. Combine with [set_httponly](set_httponly.md) to harden
session cookies.

## See also

- [set_httponly](set_httponly.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `create_cookie()` in
`lib/Vend/Server.pm`.
