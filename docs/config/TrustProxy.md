# TrustProxy

Designates IP addresses or hostnames as trusted HTTP proxies, so that for
requests coming from them Interchange believes the `X-Forwarded-For` header and
uses the forwarded client address as the remote host. Reach for it when
Interchange sits behind a reverse proxy or load balancer.

**Scope:** global (`interchange.cfg`)

## Syntax

    TrustProxy  entry ...

A comma- or whitespace-separated list of CIDR blocks, IPv6 addresses, or
DOS-style wildcard patterns (`*` matches any run of characters, `?` matches one
character). The list is compiled into an anchored, case-insensitive regular
expression. Default: empty (no proxy is trusted; the direct connecting address
is always used).

## Description

When a request arrives from an address matching `TrustProxy`, Interchange reads
the `HTTP_X_FORWARDED_FOR` value that the proxy set and treats the client
address listed there as the real remote host -- the value you see in
`[data session host]`. When the request does not come from a trusted proxy, or
`TrustProxy` is empty, the forwarded header is ignored and the actual connecting
address is used.

Without this directive, every request from a front-end proxy appears to come
from the proxy's address, so all clients share one remote host -- effectively
the behavior of [WideOpen](WideOpen.md) -- which makes session hijacking easy.
`TrustProxy` restores per-client addressing while keeping the header
trustworthy.

## Examples

Trust the local proxy and one internal address (in `interchange.cfg`):

```
TrustProxy  127.0.0.1 192.168.8.4
```

Trust a range using wildcards:

```
TrustProxy  127.0.0.? 10.0.* 192.168.?.1
```

Trust any proxy -- only for closed environments, since it believes every
`X-Forwarded-For` header:

```
TrustProxy  *
```

## Notes

The environment variables themselves are not altered; only Interchange's idea of
the remote host changes. Trusting an untrusted proxy (for example with `*`)
lets a client forge its apparent address, so scope the list as tightly as your
topology allows.

## See also

[WideOpen](WideOpen.md), [Mall](Mall.md), [IpHead](IpHead.md),
[IpQuad](IpQuad.md), [HostnameLookups](HostnameLookups.md), the
[sessions](../guides/sessions.md) and [security](../guides/security.md) guides.

## Source

Parsed by `parse_list_wildcard_cidr` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm` via `$Global::TrustProxy` when the remote host is
determined.
