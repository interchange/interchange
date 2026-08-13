# DNSBL

Lists real-time DNS blocklist servers that Interchange queries to decide whether
to reject a client by IP address. Reach for it to block requests coming from
known-bad hosts such as open proxies.

**Scope:** global (`interchange.cfg`)

## Syntax

    DNSBL  hostname ...

A whitespace- or comma-separated list of blocklist zone hostnames, appended to
an array. Default: empty (no blocklist checking).

## Description

When `DNSBL` is set, at the start of each request Interchange reverses the
client IP address into a DNS lookup name and appends each configured zone,
issuing a `gethostbyname` lookup for `reversed-ip.zone` (for example
`1.0.0.127.opm.blitzed.org`). If any zone resolves the address, the request is
treated as blocked: Interchange returns an HTTP `403 Forbidden` with a "Listed
on avoid list." message and aborts the request (`lib/Vend/Server.pm`).

Each entry is a blocklist zone name; the client's address is prepended in
reversed-octet form at lookup time, so you configure only the zone.

## Examples

Query several public blocklists in `interchange.cfg`:

```
DNSBL cbl.abuseat.org sbl-xbl.spamhaus.org
```

## Notes

The lookup adds a DNS round-trip per configured zone to every request, so keep
the list short and use responsive blocklist providers. Many fraudulent orders
originate from open proxies; blocking open-proxy zones can reduce that traffic,
at the risk of occasionally rejecting a legitimate visitor behind such an
address.

## See also

[RobotIP](RobotIP.md), [TrustProxy](TrustProxy.md),
[LockoutCommand](LockoutCommand.md), [HammerLock](HammerLock.md), the
[security](../guides/security.md) guide.

## Source

Parsed by `parse_array` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm` (`$Global::DNSBL`).
