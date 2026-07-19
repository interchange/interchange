# DomainTail

Controls whether only the tail (top-level portion) of a client's hostname is
used when qualifying a session by host. Reach for it to let visitors behind
multiple proxy servers in the same domain keep one session.

**Scope:** global (`interchange.cfg`)

## Syntax

    DomainTail  yes|no

A yes/no boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default:
`Yes` (enabled).

## Description

Interchange can tie a session to the client's resolved hostname as an extra
check that a session ID is being presented from the same origin. With
`DomainTail` on, only the domain tail is used: a host such as
`ri01-053.dialin.iskon.hr` is reduced to `iskon.hr`. This lets a visitor whose
requests come from different proxy machines within one domain stay on a single
session.

The reduction keeps the last two labels for country second-level domains listed
in [CountrySubdomains](CountrySubdomains.md) and the last label plus the TLD
otherwise (`lib/Vend/Dispatch.pm`). When `DomainTail` is off, Interchange falls
back to the [IpHead](IpHead.md)/[IpQuad](IpQuad.md) IP-based qualification
instead.

## Examples

Disable domain-tail qualification in `interchange.cfg`:

```
DomainTail No
```

## Notes

This directive is a deliberate compromise on security in favor of compatibility
with visitors who do not accept cookies and use multiple proxy servers. It is
enabled by default. If you encrypt credit cards or use payment services and want
even broader browser compatibility, see [WideOpen](WideOpen.md), which relaxes
qualification further at a further cost in security.

## See also

[CountrySubdomains](CountrySubdomains.md), [IpHead](IpHead.md),
[IpQuad](IpQuad.md), [WideOpen](WideOpen.md),
[HostnameLookups](HostnameLookups.md), the
[sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Dispatch.pm` (`$Global::DomainTail`).
