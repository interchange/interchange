# VendURL

Sets the base URL of the catalog's link program -- the entry point through
which all Interchange page requests are routed. Reach for it in every
catalog: it is what Interchange writes into generated links so the browser
comes back to the right place.

**Scope:** catalog (`catalog.cfg`)

The directive [URL](URL.md) is an alias for `VendURL`.

## Syntax

    VendURL  url

A URL string; `parse_url` strips any trailing slashes. Default: none
(undefined) -- `VendURL` is effectively required in every `catalog.cfg`.

## Description

`VendURL` is the base address Interchange uses when it builds links back to
itself. Every [page](../tags/page.md)/[area](../tags/area.md) link and every
generated form action is constructed by appending the page path (and session
id) to this URL, so it must point at the catalog's link program (usually a
CGI or `nph-` entry under `cgi-bin`). It is read from `$Vend::Cfg->{VendURL}`
throughout `lib/Vend/Interpolate.pm`, `lib/Vend/Util.pm`, and
`lib/Vend/Dispatch.pm`.

For secure (HTTPS) links Interchange uses [SecureURL](SecureURL.md); pages
marked secure are linked through that instead. `VendURL` covers ordinary
(HTTP) traffic.

## Examples

Set the catalog entry point (in `catalog.cfg`):

```
VendURL  http://www.example.com/cgi-bin/ic/tutorial
```

The strap demo builds it from variables so one setting drives the whole
catalog:

```
VendURL    http://__SERVER_NAME____CGI_URL__
SecureURL  __SECURE_SERVER____CGI_URL__
```

## Notes

The value may also be a relative path, with or without protocol and
hostname. Trailing slashes are removed during parsing, so
`http://host/cgi-bin/ic/cat/` and `.../cat` are equivalent.

## See also

[URL](URL.md), [SecureURL](SecureURL.md), [PostURL](PostURL.md),
[ImageDir](ImageDir.md), [page](../tags/page.md), [area](../tags/area.md),
the [catalog-anatomy](../guides/catalog-anatomy.md) and
[configuration](../guides/configuration.md) guides.

## Source

Parsed by `parse_url` in `lib/Vend/Config.pm`; consumed when building links
in `lib/Vend/Interpolate.pm`, `lib/Vend/Util.pm`, and `lib/Vend/Dispatch.pm`.
