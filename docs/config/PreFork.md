# PreFork

Runs the server in pre-fork mode, where a pool of child processes is started
ahead of time and waits for client connections. Reach for it on a busy site
to avoid the cost of forking a new process for every request.

**Scope:** global (`interchange.cfg`)

## Syntax

    PreFork  Yes|No

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default: `No`.

## Description

Without pre-forking, Interchange forks a fresh child to handle each incoming
connection. With `PreFork Yes`, the master instead maintains a standing pool
of idle children -- sized by [StartServers](StartServers.md), grown up to
[MaxServers](MaxServers.md) as load demands -- that are ready to serve
requests immediately. This removes per-request fork overhead and is the
recommended mode for high-traffic servers. The mode is driven from the main
accept loop in `lib/Vend/Server.pm`.

Regardless of this setting, each child still retires after handling
[MaxRequestsPerChild](MaxRequestsPerChild.md) requests and is replaced, which
bounds the effect of any memory growth in long-lived children.

## Examples

Enable pre-fork mode with a warm pool of five servers (in
`interchange.cfg`):

```
PreFork             Yes
PreForkSingleFork   Yes
StartServers        5
MaxServers          0
MaxRequestsPerChild 100
```

## Notes

Pair `PreFork` with [PreForkSingleFork](PreForkSingleFork.md), which uses a
single fork per new server; turn the single-fork option off only if zombie
processes accumulate on your platform.

## See also

[PreForkSingleFork](PreForkSingleFork.md), [StartServers](StartServers.md),
[MaxServers](MaxServers.md), [MaxRequestsPerChild](MaxRequestsPerChild.md),
the [performance](../guides/performance.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Global::PreFork` in `lib/Vend/Server.pm`.
