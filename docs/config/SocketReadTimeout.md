# SocketReadTimeout

Sets how many seconds Interchange waits for data to arrive on a client socket
before giving up on that read.

**Scope:** global (`interchange.cfg`)

## Syntax

    SocketReadTimeout  SECONDS

`SECONDS` is an integer (parser type `integer`). Default: `1` second, which
matches the fixed timeout used before this directive existed.

## Description

While reading a request from a connected client, the server uses
`SocketReadTimeout` as the `select()` timeout on the socket. If no data is
available within the interval, the read attempt times out. Raise the value on
slow or congested networks where a legitimate client may pause longer than one
second between packets.

## Examples

Wait up to five seconds for client data:

```
SocketReadTimeout 5
```

## See also

[SocketFile](SocketFile.md), [SocketPerms](SocketPerms.md).

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm` (stored in
`$Global::SocketReadTimeout`); consumed in `lib/Vend/Server.pm`, where it is the
timeout passed to `select()` (falling back to `1` if unset).
