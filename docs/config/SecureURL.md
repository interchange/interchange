# SecureURL

Sets the base URL Interchange uses to build links to itself when a page must be
served over a secure (HTTPS) connection. Reach for it to define the `https://`
entry point that pairs with the plain-HTTP [VendURL](VendURL.md).

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SecureURL  url

A URL string (trailing slashes are stripped). It may include the protocol and
host (`https://host/cgi-bin/cat`) or be a relative path. Default: unset.

## Description

Interchange Tag Language (ITL) link tags such as `[page]` and `[area]` build
their `href` from either the ordinary catalog URL ([VendURL](VendURL.md)) or the
secure one. Interchange chooses `SecureURL` when a link is generated with
`secure=1`, when the requested page matches [AlwaysSecure](AlwaysSecure.md) or
[AlwaysSecureGlob](AlwaysSecureGlob.md), or when the current request is itself
secure and `match_security` is in effect.

If `SecureURL` is unset, secure links cannot be built; set it to the HTTPS form
of your catalog's link program.

## Examples

Point secure links at the catalog's HTTPS URL. In `catalog.cfg`:

```
VendURL    http://www.example.com/cgi-bin/cat
SecureURL  https://www.example.com/cgi-bin/cat
```

The strap demo derives it from configuration variables, and falls back to the
plain URL when secure serving is disabled:

```
SecureURL  __SECURE_SERVER____CGI_URL__

ifndef SECURE_ENABLE
SecureURL  http://__SERVER_NAME____CGI_URL__
endif
```

## See also

[VendURL](VendURL.md), [SecurePostURL](SecurePostURL.md),
[PostURL](PostURL.md), [AlwaysSecure](AlwaysSecure.md),
[AlwaysSecureGlob](AlwaysSecureGlob.md), [ImageDirSecure](ImageDirSecure.md),
the [security](../guides/security.md) guide.

## Source

Parsed by `parse_url` in `lib/Vend/Config.pm`. Consumed in
`lib/Vend/Util.pm` (`vendUrl`, `secure_vendUrl`).
