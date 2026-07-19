# HostnameLookups

Controls whether Interchange resolves each visitor's IP address to a DNS
hostname. Reach for it only when a feature needs the hostname (such as
[RobotHost](RobotHost.md)) and your web server is not already supplying it.

**Scope:** global (`interchange.cfg`)

## Syntax

    HostnameLookups  yes|no

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`). Default: `No`.

## Description

When enabled, Interchange performs a reverse DNS lookup on the remote IP address
to obtain the client hostname, making it available for host-based rules and
logging. When disabled (the default), no lookup is done and only the IP address
is known.

DNS lookups add latency to requests, so leave this off unless a feature depends
on hostnames. Host-based robot detection with [RobotHost](RobotHost.md) needs
it; if you only need address-based matching, use [RobotIP](RobotIP.md) instead
and keep lookups off. If the web server in front of Interchange already resolves
hostnames and passes them through, leave this directive disabled to avoid
duplicate lookups.

## Examples

Enable reverse DNS resolution (`interchange.cfg`):

```
HostnameLookups Yes
```

## See also

[RobotHost](RobotHost.md), [RobotIP](RobotIP.md), [RobotUA](RobotUA.md),
[TrustProxy](TrustProxy.md), the [performance](../guides/performance.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm` and `lib/Vend/Dispatch.pm`, which resolve the remote
hostname when `$Global::HostnameLookups` is set.
