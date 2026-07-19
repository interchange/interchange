# PostURL

Sets the catalog URL used as the form-action target for POST submissions,
letting POST requests take a different path than GET requests. Reach for it
when your web server routes POSTs to the CGI link but serves GETs from
static-looking URLs.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    PostURL  url

A URL string; trailing slashes are stripped. The value may be a full URL
(with protocol and host) or a relative path. Default: empty (the
[process](../tags/process.md) tag falls back to [VendURL](VendURL.md)).

## Description

The [process](../tags/process.md) tag builds the action URL for a form. For
a non-secure submission it uses `PostURL` if set, otherwise
[VendURL](VendURL.md); for a secure submission it uses
[SecurePostURL](SecurePostURL.md) if set, otherwise
[SecureURL](SecureURL.md). This is what lets a catalog present ordinary GET
links that look like a static site while still POSTing forms to the
Interchange CGI link. The selection happens in
`code/SystemTag/process.coretag`.

Use `PostURL` together with [AcceptRedirect](AcceptRedirect.md) and a web
server configured to redirect page and index requests into Interchange when
you want the catalog to behave like a static HTML site for GET traffic.

## Examples

Point GET and POST traffic at different paths (in `catalog.cfg`):

```
VendURL        http://www.example.com/
SecureURL      https://www.example.com/
PostURL        http://www.example.com/cgi-bin/store
SecurePostURL  https://www.example.com/cgi-bin/store
```

A form then uses the [process](../tags/process.md) tag as its action:

```
<form method="post" action="[process]">
```

## See also

[SecurePostURL](SecurePostURL.md), [VendURL](VendURL.md),
[SecureURL](SecureURL.md), [AcceptRedirect](AcceptRedirect.md),
[process](../tags/process.md), the [forms](../guides/forms.md) guide.

## Source

Parsed by `parse_url` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{PostURL}` in `code/SystemTag/process.coretag`.
