# StartServers

Sets how many page-server processes Interchange preforks when it runs in
[PreFork](PreFork.md) mode. Preforking a pool of servers avoids the cost of
forking one per request under load.

**Scope:** global (`interchange.cfg`)

## Syntax

    StartServers  COUNT

`COUNT` is an integer (parser type `integer`). Default: `0`. A value greater
than `150` is rejected at startup as unreasonably large.

## Description

`StartServers` has effect only when [PreFork](PreFork.md) is enabled. At startup
Interchange forks `StartServers` page servers and keeps the pool topped up to
that number as servers exit, so requests are handed to an already-running
process instead of forking on demand. In the default (non-PreFork) mode, a
server is forked per connection and `StartServers` is unused.

This is the page-service counterpart of
[SOAP_StartServers](SOAP_StartServers.md).

## Examples

Prefork five page servers (from `interchange.cfg`):

```
PreFork      Yes
StartServers 5
MaxServers   0
```

## Notes

For background on Interchange's run modes and their tradeoffs, see the
[performance](../guides/performance.md) guide.

## See also

[PreFork](PreFork.md), [MaxServers](MaxServers.md),
[MaxRequestsPerChild](MaxRequestsPerChild.md),
[SOAP_StartServers](SOAP_StartServers.md).

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm` (stored in
`$Global::StartServers`); consumed by the prefork server pool logic in
`lib/Vend/Server.pm`.
