# SOAP_MaxRequests

Sets how many SOAP-RPC requests one SOAP server process handles before it exits
and is respawned. Periodic respawning limits the effect of any memory leaks in
long-running server processes.

**Scope:** global (`interchange.cfg`)

## Syntax

    SOAP_MaxRequests  COUNT

`COUNT` is an integer (parser type `integer`; decimal, `0x` hex, or leading-`0`
octal are accepted). Default: `50`. If the configured value is ever empty or
zero, the server falls back to a hard-coded limit of `10`.

## Description

Each SOAP server process counts the requests it has served; once the count
exceeds `SOAP_MaxRequests`, the process finishes the current request and shuts
down, and the parent starts a replacement. This is the SOAP-side analogue of
[MaxRequestsPerChild](MaxRequestsPerChild.md) for ordinary page servers.

The value is read at startup and applies to every SOAP server process launched
by [SOAP_StartServers](SOAP_StartServers.md). SOAP must be enabled globally
with [SOAP](SOAP.md) for this to matter.

## Examples

Recycle each SOAP server after 200 requests:

```
SOAP_MaxRequests 200
```

## See also

[SOAP](SOAP.md), [SOAP_StartServers](SOAP_StartServers.md),
[SOAP_Socket](SOAP_Socket.md),
[MaxRequestsPerChild](MaxRequestsPerChild.md).

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm` (stored in
`$Global::SOAP_MaxRequests`); consumed in `lib/Vend/Server.pm`, where a process
respawns once it has handled more than `$Global::SOAP_MaxRequests || 10`
requests.
