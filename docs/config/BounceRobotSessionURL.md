# BounceRobotSessionURL

Redirects a robot's GET request that carries an explicit `mv_session_id`
to the same URL with the session ID removed. Reach for it to stop search
engines from indexing many session-salted copies of the same page.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    BounceRobotSessionURL  Yes|No

A yes/no boolean (`yes`/`no`, `true`/`false`, `1`/`0`, `on`/`off`,
case-insensitive). Default: `No`.

## Description

When this directive is on and a request comes from a client identified as
a robot (`$Vend::Robot`) with a session ID supplied in the URL, the
dispatch code in `lib/Vend/Dispatch.pm` issues a `301 Moved` redirect to
the same path without the `mv_session_id`. This keeps
redirect-respecting search engines from storing session-salted URLs and
focuses them on a single canonical URL per resource.

It is the session-ID counterpart to `BounceReferralsRobot`, which strips
affiliate codes; the two are evaluated together in the same dispatch
check.

## Examples

Strip session IDs from robot request URLs (in `catalog.cfg`):

```
BounceRobotSessionURL yes
```

## Notes

Only robot requests are affected, so ordinary shoppers whose session is
carried in the URL are not redirected. Robot identification comes from the
robot-detection directives (`RobotUA`, `RobotIP`, `RobotHost`).

## See also

[BounceReferralsRobot](BounceReferralsRobot.md), [BounceReferrals](BounceReferrals.md), [RobotUA](RobotUA.md), [RobotIP](RobotIP.md),
[RobotHost](RobotHost.md), the [sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{BounceRobotSessionURL}` in `lib/Vend/Dispatch.pm`.
