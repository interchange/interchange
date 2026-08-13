# SOAP

Enables Interchange's SOAP RPC server. At global scope it turns the SOAP
listener subsystem on for the daemon; at catalog scope it marks an individual
catalog as reachable through SOAP. Reach for it to expose Interchange tags and
actions to remote programs over SOAP.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    SOAP  yes|no

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default: `No` at
both scopes.

## Description

### Global

In `interchange.cfg`, `SOAP Yes` enables the SOAP server type: Interchange
spawns SOAP server processes (governed by [SOAP_Socket](SOAP_Socket.md),
`SOAP_Perms`, `SOAP_MaxRequests`, and `SOAP_StartServers`) that listen for RPC
requests, and respawns them on a reconfigure. Without the global switch on, no
SOAP listeners run regardless of catalog settings. This is read at startup.

### Catalog

In `catalog.cfg`, `SOAP` marks the catalog as SOAP-enabled. When a SOAP request
names a catalog whose `SOAP` is not set, Interchange returns a
`Service not available` fault. Only with the catalog flag on does it dispatch
the request -- to a [SOAP_Action](SOAP_Action.md) handler or an allowed tag. The
related [SOAP_Enable](SOAP_Enable.md) hash toggles finer options, such as whether
tag output is interpolated.

## Examples

Turn the SOAP subsystem on for the server. In `interchange.cfg`:

```
SOAP Yes
```

Make a catalog answer SOAP requests. In `catalog.cfg`:

```
SOAP Yes
```

## See also

[SOAP_Action](SOAP_Action.md), [SOAP_Enable](SOAP_Enable.md),
[SOAP_Socket](SOAP_Socket.md), [SOAP_Control](SOAP_Control.md).

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm` at both scopes. The global flag
is consumed via `$Global::SOAP` in `lib/Vend/Server.pm` (server spawning and
`SOAP` server type); the catalog flag via `$Vend::Cfg->{SOAP}` in
`lib/Vend/Server.pm` (SOAP request dispatch).
