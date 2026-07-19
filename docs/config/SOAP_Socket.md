# SOAP_Socket

Lists the sockets Interchange listens on for SOAP-RPC requests. Each entry is
either a Unix-domain socket path or an Inet `host:port` address.

**Scope:** global (`interchange.cfg`)

## Syntax

    SOAP_Socket  ENTRY [ENTRY ...]

The value is a whitespace/comma-separated list (parser type `array`) that is
appended to across multiple lines. Each entry is interpreted as follows:

- An entry containing `/` is treated as a **Unix-domain socket** path (for
  example `/var/run/interchange/soap`).
- Any other entry is treated as an **Inet socket**, in the form
  `host:port`, `ip:port`, or a bare `port` (the address and colon are
  optional).

Default: empty. If [SOAP](SOAP.md) is enabled and no `SOAP_Socket` is given,
Interchange defaults to an Inet socket on port `7780`.

## Description

At startup Interchange opens a listener for every entry. Multiple entries let
the server accept SOAP requests on several addresses or on both Inet and Unix
sockets at once. Unix-socket files get the mode set by
[SOAP_Perms](SOAP_Perms.md).

This is the SOAP counterpart of [SocketFile](SocketFile.md) (Unix) and
`TcpMap`/`TcpHost` (Inet) for ordinary page service.

## Examples

Listen on a single Unix-domain socket:

```
SOAP_Socket /var/run/interchange/interchange.soap
```

Listen on two Inet addresses and a Unix socket at once:

```
SOAP_Socket 12.23.13.31:7770 1.2.3.4:7770 /var/run/interchange/soap
```

## See also

[SOAP](SOAP.md), [SOAP_Perms](SOAP_Perms.md),
[SOAP_StartServers](SOAP_StartServers.md), [SocketFile](SocketFile.md).

## Source

Parsed by `parse_array` in `lib/Vend/Config.pm` (stored in
`$Global::SOAP_Socket`; the port `7780` default is applied in postprocessing
when SOAP is enabled); consumed by the SOAP server loop in `lib/Vend/Server.pm`.
