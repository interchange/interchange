# Unix_Mode

Controls whether the Interchange server listens on a Unix-domain socket. Reach
for it to turn the Unix socket off (for example when running purely in Inet
mode) or to confirm it is on.

**Scope:** global (`interchange.cfg`)

## Syntax

    Unix_Mode  Yes|No

A boolean (`Yes`/`No`, `1`/`0`, `on`/`off`). Default: `Yes` -- unless a mode was
set on the command line, in which case the command-line choice wins. If neither
`Inet_Mode` nor `Unix_Mode` is specified anywhere, `Unix_Mode` is `Yes` and
[Inet_Mode](Inet_Mode.md) is `No`.

## Description

With `Unix_Mode` enabled, Interchange opens a Unix-domain socket (see
[SocketFile](SocketFile.md), [SocketPerms](SocketPerms.md)) and the link program
communicates with the daemon through it. Unix mode is the usual configuration
because the socket is local and file-permission protected. A server may run Unix
mode, Inet mode, or both at once.

The command-line switch `interchange -u` forces Unix mode on regardless of the
configured value.

## Examples

Disable the Unix socket, for example to run Inet-only (in `interchange.cfg`):

```
Inet_Mode  Yes
Unix_Mode  No
```

## See also

[Inet_Mode](Inet_Mode.md), [SocketFile](SocketFile.md),
[SocketPerms](SocketPerms.md), [TcpMap](TcpMap.md), [TcpHost](TcpHost.md), the
[installation](../guides/installation.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm` via `$Global::Unix_Mode` when the listening sockets are
opened.
