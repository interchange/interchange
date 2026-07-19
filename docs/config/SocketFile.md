# SocketFile

Names the Unix-domain socket file(s) Interchange creates for communication with
the web-server link program (`vlink`/`tlink`) and other local clients.

**Scope:** global (`interchange.cfg`)

## Syntax

    SocketFile  PATH [PATH ...]

The value is a shell-quoted list of paths (parser type `root_dir_array`). Each
path is made absolute against the Interchange root directory, and multiple
`SocketFile` lines accumulate into a list, so the server can listen on more than
one Unix socket. Default: empty.

## Description

At startup Interchange creates each named socket file and listens on it for
Unix-domain connections; the link program compiled into your CGI directory
connects to this path to hand requests to the daemon. The socket file must live
where the Interchange daemon can create it and the link program can reach it,
and its permissions are set by [SocketPerms](SocketPerms.md).

`SocketFile` governs Unix-mode service; Inet-mode (TCP) service is configured
separately with `TcpMap` and `TcpHost`.

## Examples

Listen on a single Unix socket:

```
SocketFile /var/run/interchange/interchange.sock
```

## Notes

You use `SocketFile` together with the `vlink` link program that Interchange
compiles for your web server. The `MINIVEND_SOCKET` environment variable
described in some older documentation is **not** honored.

## See also

[SocketPerms](SocketPerms.md),
[SocketReadTimeout](SocketReadTimeout.md), [SOAP_Socket](SOAP_Socket.md), the
[installation](../guides/installation.md) guide.

## Source

Parsed by `parse_root_dir_array` in `lib/Vend/Config.pm` (stored in
`$Global::SocketFile`); consumed by the server's Unix-socket listener setup in
`lib/Vend/Server.pm`.
