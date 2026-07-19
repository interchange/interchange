# IpHead

Qualifies user sessions by only the leading portion of the client's IP
address instead of the whole address. Reach for it to let visitors behind
rotating proxy pools (which change the client IP between requests) keep a
single session without cookies.

**Scope:** global (`interchange.cfg`)

## Syntax

    IpHead  yes|no

Boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default: `No`.

## Description

Interchange can bind a session to the requesting IP address as an
anti-hijacking measure. When `IpHead` is enabled, only the first
[IpQuad](IpQuad.md) octets ("dot-quads") of the IPv4 address are used for
that binding, rather than the full address. A visitor whose proxy changes
the last octets between requests then still matches the same session.

This is a slight relaxation of session security, traded for compatibility
with multi-proxy clients that do not accept cookies. If `IpQuad` is `0`,
the IP is treated as `nobody` (no IP qualification at all).

The directive is read at server startup and applies to all catalogs.

## Examples

Qualify sessions on the first three octets (put in `interchange.cfg`):

```
DomainTail No
IpHead     Yes
IpQuad     3
```

## Notes

[DomainTail](DomainTail.md) is the preferred mechanism unless one of your
HTTP servers does not perform hostname lookups. `IpHead` and `DomainTail`
address the same session-qualification concern by different means.

## See also

[IpQuad](IpQuad.md), [DomainTail](DomainTail.md), [WideOpen](WideOpen.md),
[CountrySubdomains](CountrySubdomains.md), the
[sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`Vend::Dispatch` (`lib/Vend/Dispatch.pm`).
