# Inet_Mode

Controls whether the Interchange server opens an INET-domain (TCP) socket
and listens on a port. Reach for it when the web server and Interchange run
on different machines and must communicate over TCP.

**Scope:** global (`interchange.cfg`)

## Syntax

    Inet_Mode  yes|no

Boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default: `No`
(computed -- see below).

## Description

When `Inet_Mode` is on, the server listens on an INET (TCP) socket, port
`7786` by default. Change the port with the [TcpMap](TcpMap.md) directive.
This is required when the web server (running the link CGI, `tlink`) and
the Interchange daemon are on different hosts.

`Inet_Mode` and [Unix_Mode](Unix_Mode.md) together select the socket
type(s). Their defaults are computed from each other at startup: if neither
is set anywhere, the server comes up in Unix-socket mode only
(`Unix_Mode` yes, `Inet_Mode` no). If one is set explicitly, the other
defaults to off unless it too is set. Both may be enabled at once to listen
on both socket types.

The setting can be overridden on the command line with the
`interchange -i` switch. It is read at server startup only.

## Examples

Enable TCP listening (put in `interchange.cfg`):

```
Inet_Mode Yes
```

Together with a non-default port via `TcpMap`:

```
Inet_Mode Yes
TcpMap 7786 -
```

## Notes

The default port `7786` was chosen because 77 and 86 are the ASCII codes
for `M` and `V` -- Interchange was formerly named MiniVend.

## See also

[Unix_Mode](Unix_Mode.md), [TcpMap](TcpMap.md), [TcpHost](TcpHost.md),
[SocketFile](SocketFile.md), the
[architecture](../guides/architecture.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm` (default derived from
`$Global::Inet_Mode` / `$Global::Unix_Mode`); consumed in
`lib/Vend/Server.pm`.
