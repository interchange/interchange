# SOAP_Perms

Sets the Unix filesystem permissions on the SOAP-RPC socket file that
Interchange creates when SOAP listens on a Unix-domain socket.

**Scope:** global (`interchange.cfg`)

## Syntax

    SOAP_Perms  MODE

`MODE` is an integer (parser type `integer`). Prepend a leading `0` to write it
in octal, as you normally would for a file mode. Default: `0600`, which lets
only processes running under the Interchange server's UID open the socket.

## Description

When [SOAP_Socket](SOAP_Socket.md) names a Unix-domain socket (a path
containing `/`), Interchange creates that socket file and applies the
`SOAP_Perms` mode to it. The setting has no effect on Inet (`host:port`) SOAP
sockets.

Loosen the mode only when another local process running under a different UID
must reach the SOAP socket. A world-accessible mode such as `0666` is a
security risk and is best reserved for short-term debugging.

## Examples

Make the SOAP socket world-accessible (for debugging only):

```
SOAP_Perms 0666
```

## Notes

The historic manuals gave the default as `0660`; the current source sets it to
`0600`.

## See also

[SOAP](SOAP.md), [SOAP_Socket](SOAP_Socket.md), [SocketPerms](SocketPerms.md),
[SocketFile](SocketFile.md).

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm` (stored in
`$Global::SOAP_Perms`); applied to the SOAP socket file in `lib/Vend/Server.pm`.
