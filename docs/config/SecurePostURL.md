# SecurePostURL

Sets the base URL Interchange uses for secure (HTTPS) form submissions built
with the `[process]` tag. Reach for it when secure POST requests should go to a
different path than secure GET links.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SecurePostURL  url

A URL string (trailing slashes are stripped), with or without protocol and
host. Default: empty.

## Description

The `[process]` Interchange Tag Language (ITL) tag builds the `action` target of
a form. It normally uses [PostURL](PostURL.md) for insecure submissions and
`SecurePostURL` for secure ones, letting form POSTs use a different entry point
than ordinary GET links do. If `SecurePostURL` is empty, secure form actions
fall back to [SecureURL](SecureURL.md).

This directive supports setups behind Apache where static-looking GET links and
dynamic POST actions are served through different paths -- see
[AcceptRedirect](AcceptRedirect.md).

## Examples

Give secure form POSTs their own HTTPS entry point. In `catalog.cfg`:

```
VendURL        http://www.example.com/
SecureURL      https://www.example.com/
PostURL        http://www.example.com/cgi-bin/cat
SecurePostURL  https://www.example.com/cgi-bin/cat
```

A form then targets it with:

```
<form action="[process secure=1]" method="POST">
```

## See also

[PostURL](PostURL.md), [SecureURL](SecureURL.md), [VendURL](VendURL.md),
[AcceptRedirect](AcceptRedirect.md), the [forms](../guides/forms.md) and
[security](../guides/security.md) guides.

## Source

Parsed by `parse_url` in `lib/Vend/Config.pm`. Consumed by the `[process]`
tag in `code/SystemTag/process.coretag`
(`$Vend::Cfg->{SecurePostURL} || $Vend::Cfg->{SecureURL}`).
