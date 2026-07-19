# IPCsocket

Names the Unix-domain socket file the Interchange server creates for
inter-process control (IPC) communication, such as reconfigure and status
requests from command-line tools. Reach for it to relocate that socket,
for example onto a `tmpfs` run directory.

**Scope:** global (`interchange.cfg`)

## Syntax

    IPCsocket  PATH

A single path. It is made absolute against the Interchange root if
relative, and trailing slashes are stripped. Default: `etc/socket.ipc`
(under the Interchange root). Set it empty to disable the IPC socket.

## Description

At startup the server creates this Unix-domain socket and listens on it for
control messages -- the channel used by `interchange` command-line
operations (such as `--reconfig` and status queries) to reach the running
daemon. The path must be writable by the Interchange user.

If `IPCsocket` is empty, no IPC socket is created and control operations
that depend on it are unavailable. The directive is read at server startup
only.

## Examples

Place the IPC socket under a system run directory:

```
IPCsocket /var/run/interchange/interchange.sock.ipc
```

The default, relative to the Interchange root:

```
IPCsocket etc/socket.ipc
```

## Notes

This is distinct from the request-serving sockets configured by
[SocketFile](SocketFile.md) (Unix domain) and [TcpMap](TcpMap.md) /
[Inet_Mode](Inet_Mode.md) (TCP); `IPCsocket` carries control traffic, not
storefront page requests.

## See also

[SocketFile](SocketFile.md), [Inet_Mode](Inet_Mode.md),
[TcpMap](TcpMap.md), the [architecture](../guides/architecture.md) guide.

## Source

Parsed by `parse_root_dir` in `lib/Vend/Config.pm`; the socket is created
and serviced in `lib/Vend/Server.pm`.
