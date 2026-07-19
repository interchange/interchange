# SOAP_StartServers

Sets how many SOAP-RPC server processes Interchange starts to handle SOAP
requests.

**Scope:** global (`interchange.cfg`)

## Syntax

    SOAP_StartServers  COUNT

`COUNT` is an integer (parser type `integer`). Default: `1`. A value greater
than `150` is rejected at startup as unreasonably large.

## Description

At startup, when [SOAP](SOAP.md) is enabled and [SOAP_Socket](SOAP_Socket.md)
is configured, Interchange spawns `SOAP_StartServers` processes to service
incoming SOAP requests. Each of those processes recycles itself after
[SOAP_MaxRequests](SOAP_MaxRequests.md) requests.

Raise the count when a single SOAP server cannot keep up with concurrent
remote calls.

## Examples

Start ten SOAP server processes:

```
SOAP_StartServers 10
```

## Notes

Older documentation described any value above `50` as unreasonable; the current
server actually enforces a ceiling of `150`, dying with a "Ridiculously large
number of SOAP_StartServers" error above that.

## See also

[SOAP](SOAP.md), [SOAP_Socket](SOAP_Socket.md),
[SOAP_MaxRequests](SOAP_MaxRequests.md), [SOAP_Perms](SOAP_Perms.md),
[StartServers](StartServers.md).

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm` (stored in
`$Global::SOAP_StartServers`); consumed by `start_soap` in `lib/Vend/Server.pm`.
