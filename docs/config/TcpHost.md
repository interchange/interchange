# TcpHost

Lists the hosts allowed to connect to the Interchange server when it runs in
Inet (TCP) mode. Reach for it to restrict which machines -- typically only the
web server front end -- may open the Interchange socket.

**Scope:** global (`interchange.cfg`)

## Syntax

    TcpHost  host ...

A whitespace-, comma-, or pipe-separated list of hostnames or IP addresses. The
list is compiled into a case-sensitive regular expression that incoming
connections must match. Default: `localhost 127.0.0.1`.

## Description

In Inet mode Interchange accepts a connection only if the connecting address or
resolved hostname matches the `TcpHost` pattern; non-matching connections are
refused. Because this gate is at the socket level, it applies to every catalog
served by that Interchange daemon.

At startup the list is passed through `create_host_pattern`, which escapes dots
and joins the entries into one alternation. Each `*` in an entry is converted to
`[-\w.]+`, so simple wildcards are honored (for example `192.168.8.*`). The
`?`-style single-character wildcard is not supported.

## Examples

Allow the local host and one internal server (in `interchange.cfg`):

```
TcpHost  localhost 127.0.0.1 192.168.8.9
```

Allow an entire internal subnet with a wildcard:

```
TcpHost  127.0.0.1 192.168.8.*
```

## Notes

Historic documentation stated that `TcpHost` accepts only a plain list with no
wildcards. The current code does expand `*` into a regular-expression fragment,
so `*` wildcards work; anchoring is by regex match, not full-string, so keep
entries specific.

Running in Inet mode also requires enabling [Inet_Mode](Inet_Mode.md) and
setting up a link program; see [TcpMap](TcpMap.md) for the ports listened on.

## See also

[TcpMap](TcpMap.md), [Inet_Mode](Inet_Mode.md), [Unix_Mode](Unix_Mode.md),
[Catalog](Catalog.md), the [installation](../guides/installation.md) and
[security](../guides/security.md) guides.

## Source

Stored unparsed (no parse routine) in `lib/Vend/Config.pm`; compiled by
`create_host_pattern` and matched against connecting hosts in
`lib/Vend/Server.pm` via `$Global::TcpHost`.
