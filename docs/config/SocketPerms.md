# SocketPerms

Sets the Unix filesystem permissions on the [SocketFile](SocketFile.md)
Unix-domain socket that Interchange creates.

**Scope:** global (`interchange.cfg`)

## Syntax

    SocketPerms  MODE

`MODE` is an integer (parser type `integer`). Prepend a leading `0` to write it
in octal, as you would for any file mode. Default: `0600`, which lets only
processes running under the Interchange server's UID open the socket.

## Description

The mode is applied to every socket created from [SocketFile](SocketFile.md).
The default `0600` is the most restrictive useful value. A common alternative
is `0666`, which lets any process on the machine open the socket -- necessary,
for example, when Apache reaches the socket through `mod_perl` or the
`Interchange::Link` module while running as a different user. A world-accessible
socket is a security tradeoff; use it deliberately.

The directive can be overridden on the command line with
`interchange -r SocketPerms=MODE`.

## Examples

Make the socket accessible to any local process:

```
SocketPerms 0666
```

## Notes

If Interchange is not responding through the web server, temporarily setting
`0666` is a quick way to tell whether the problem is socket permissions rather
than something deeper.

## See also

[SocketFile](SocketFile.md), [SocketReadTimeout](SocketReadTimeout.md),
[SOAP_Perms](SOAP_Perms.md).

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm` (stored in
`$Global::SocketPerms`); applied to the socket file in `lib/Vend/Server.pm`.
