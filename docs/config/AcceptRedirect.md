# AcceptRedirect

Enables Interchange to honor HTTP redirects sent by the front-end web
server, so that an `ErrorDocument` handler can hand an unresolved URL to
Interchange for processing. Reach for it when you want Interchange to
serve pages that do not exist as static files on the web server.

**Scope:** global (`interchange.cfg`)

## Syntax

    AcceptRedirect  Yes|No

A yes/no boolean (`yes`/`no`, `true`/`false`, `1`/`0`, `on`/`off`,
case-insensitive). Default: `No`.

## Description

When set, Interchange adds the `REDIRECT_URL` environment variable to the
set of CGI variables it maps from the front-end link program, letting it
recover the originally requested path from a web-server redirect. This is
the mechanism behind serving Apache `ErrorDocument` requests through
Interchange.

For example, with this in the Apache `httpd.conf`:

```apache
ErrorDocument 404 /cgi-bin/ic/standard
```

a request for `/somedir/index.html` that the web server cannot find is
resent to `/cgi-bin/ic/standard/somedir/index.html`, and Interchange
serves it as though it were the originally requested page.

The directive is read once at server startup; changing it requires a
restart.

## Examples

Enable acceptance of web-server redirects:

```
AcceptRedirect Yes
```

## Notes

Combined with `RedirectCache`, Interchange can write the generated page
into the web server's static HTML space so that the next request is found
by the web server directly. Be aware this turns the page into a static
file.

Do not point the web server's `ErrorDocument` at Interchange for the
entire document root without care: every mistyped or probing URL then
becomes an Interchange request, exposing you to a denial-of-service load
(for example a flood of automated attacks at random URLs). Restrict the
redirect to specific directories the web server can otherwise absorb.

## See also

[RedirectCache](RedirectCache.md), the [security](../guides/security.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm` (`$Global::AcceptRedirect` controls whether
`REDIRECT_URL` is added to the CGI variable map).
