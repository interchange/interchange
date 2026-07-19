# IpQuad

Sets how many leading octets ("dot-quads") of the client IPv4 address are
used to qualify a session when [IpHead](IpHead.md) is enabled. Reach for it
to tune how much of the address must stay constant for a session to be
honored.

**Scope:** global (`interchange.cfg`)

## Syntax

    IpQuad  NUMBER

An integer (decimal, `0x` hex, or leading-`0` octal). Default: `1`.

## Description

`IpQuad` has effect only when [IpHead](IpHead.md) is on. It gives the
number of leading octets of the dotted-quad IPv4 address that Interchange
keeps when binding a session to the client IP. With an address of
`127.0.0.1` and `IpQuad 3`, the qualifier uses `127.0.0.` -- the final
octet may vary between requests without breaking the session.

A value of `0` disables IP qualification entirely (the client is treated
as `nobody`). Higher values require more of the address to match, tightening
security at the cost of proxy compatibility.

The directive is read at server startup and applies to all catalogs.

## Examples

Honor the first three octets (put in `interchange.cfg`):

```
DomainTail No
IpHead     Yes
IpQuad     3
```

## Notes

[DomainTail](DomainTail.md) is preferable unless one of your HTTP servers
does not do hostname lookups.

## See also

[IpHead](IpHead.md), [DomainTail](DomainTail.md), [WideOpen](WideOpen.md),
[CountrySubdomains](CountrySubdomains.md), the
[sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm`; consumed alongside
`IpHead` in `Vend::Dispatch` (`lib/Vend/Dispatch.pm`).
