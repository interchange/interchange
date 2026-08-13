# TcpMap

Lists the host addresses and TCP ports the Interchange server binds to when
running in Inet mode. Reach for it to change the listening port or to listen on
several addresses and ports at once.

**Scope:** global (`interchange.cfg`)

## Syntax

    TcpMap  host_and_port  catalog ...

One or more `host_and_port catalog` pairs parsed as a hash. `host_and_port` is a
bare port (`7786`), or `host:port` (`127.0.0.1:7786`, `*:7786`). The second
element was historically the catalog to bind to that port; with the built-in web
server long gone, the only sensible value now is `-`. Pairs accumulate. Default:
empty (Interchange binds all addresses on port `7786`).

## Description

In Inet mode Interchange listens on each `host:port` given in `TcpMap`. Requests
are routed to catalogs by the `SCRIPT_PATH` supplied by the link program
(`tlink`) rather than by the port, so the catalog field is a placeholder `-`.
The default port 7786 comes from the ASCII values of `M` and `V`
("MiniVend").

## Examples

The stock `interchange.cfg` binds the default port:

```
TcpMap 7786 -
```

Listen on three ports:

```
TcpMap 7786 - 7787 - 7788 -
```

Bind several specific addresses and ports with a here-document:

```
TcpMap <<EOD
  *:7786          -
  127.0.0.1:7787  -
  *:7789          -
EOD
```

## Notes

To offer a specific catalog "on its own port," use web-server location aliases
and Interchange script-path aliases in the [Catalog](Catalog.md) definition
rather than `TcpMap`; the port itself no longer selects a catalog.

## See also

[TcpHost](TcpHost.md), [Inet_Mode](Inet_Mode.md), [Unix_Mode](Unix_Mode.md),
[SocketFile](SocketFile.md), [Catalog](Catalog.md), the
[installation](../guides/installation.md) guide.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm` via `$Global::TcpMap` when the Inet sockets are opened.
