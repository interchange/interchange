# NotRobotUA

Lists user-agent strings that must never be classified as robots (crawlers or
search-engine spiders). Reach for it when a legitimate client is being wrongly
treated as an unattended bot because it matches [RobotUA](RobotUA.md).

**Scope:** global (`interchange.cfg`)

## Syntax

    NotRobotUA  wildcard ...

A list of DOS-style wildcard patterns (`*`, `?`, `{a,b}`), one per token,
compiled together into a single case-insensitive regular expression. Multiple
lines accumulate. Default: empty (no user agents are exempted).

## Description

On each request `lib/Vend/Server.pm` decides whether the client is a robot. If
the incoming `User-Agent` matches the compiled `NotRobotUA` pattern the client
is left as an ordinary visitor and the [RobotUA](RobotUA.md) test is skipped
entirely. `NotRobotUA` therefore takes priority over `RobotUA`: an agent that
matches both is treated as human.

Robot classification affects session handling -- flagged robots get a temporary,
non-persistent session -- so exempting a well-behaved agent here restores normal
session and cookie behavior for it.

The pattern is compiled once at server startup, so changes take effect on the
next restart.

## Examples

Never treat a monitoring agent that contains `wget` as a robot (in
`interchange.cfg`):

```
NotRobotUA *wget*
```

## See also

[RobotUA](RobotUA.md), [RobotIP](RobotIP.md), [RobotHost](RobotHost.md),
[RobotLimit](RobotLimit.md), the [sessions](../guides/sessions.md) guide and the
[glossary](../glossary.md).

## Source

Parsed by `parse_list_wildcard` in `lib/Vend/Config.pm`; consumed via
`$Global::NotRobotUA` in `lib/Vend/Server.pm`.
