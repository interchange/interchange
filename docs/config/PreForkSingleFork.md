# PreForkSingleFork

Makes pre-fork mode start each pool server with one `fork()` instead of two.
Reach for it, together with [PreFork](PreFork.md), to minimize forking
overhead on a busy server.

**Scope:** global (`interchange.cfg`)

## Syntax

    PreForkSingleFork  Yes|No

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default: `No`.

## Description

This directive only matters when [PreFork](PreFork.md) is enabled. When on,
Interchange performs a single `fork()` per new pool server rather than the
double-fork it would otherwise use, reducing system overhead as the server
pool is (re)populated. The behavior is applied in the pre-fork paths of
`lib/Vend/Server.pm`, which test `$Global::PreFork && $Global::PreForkSingleFork`.

The double-fork technique exists to keep child processes from becoming
zombies on some platforms. Single-forking is faster, so it is the
recommended setting; turn it off only if you observe zombie processes
piling up.

## Examples

Enable pre-fork with single forking (in `interchange.cfg`):

```
PreFork             Yes
PreForkSingleFork   Yes
```

## See also

[PreFork](PreFork.md), [StartServers](StartServers.md),
[MaxServers](MaxServers.md), the [performance](../guides/performance.md)
guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Global::PreForkSingleFork` in `lib/Vend/Server.pm`.
