# BounceReferralsRobot

Strips the affiliate/source code from a GET request's URL -- as
`BounceReferrals` does -- but only when the request comes from a client
identified as a robot. Reach for it when you want clean, canonical URLs
for crawlers and analytics without redirecting ordinary shoppers.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    BounceReferralsRobot  Yes|No

A yes/no boolean (`yes`/`no`, `true`/`false`, `1`/`0`, `on`/`off`,
case-insensitive). Default: `No`.

## Description

This directive works exactly like `BounceReferrals`, but the redirect that
removes the `mv_pc`/`mv_source` code from the URL fires only when the
current request is flagged as a robot (`$Vend::Robot`, set from the robot
detection directives such as `RobotUA`). The check is made in
`lib/Vend/Dispatch.pm` alongside the `BounceReferrals` test.

Enabling it lets you leave affiliate codes visible in the URLs served to
real users while still presenting a single canonical URL to search
engines.

## Examples

Bounce affiliate codes for robots only (in `catalog.cfg`):

```
BounceReferralsRobot yes
```

## Notes

This is useful when analytics tools (for example Google Analytics or
Adobe/Omniture SiteCatalyst) need to see the referral code in the URL for
human traffic, while search-engine crawlers should still be redirected to
the clean URL for SEO. `BounceReferrals` (unconditional) and this
robot-only variant can be set independently.

## See also

[BounceReferrals](BounceReferrals.md), [BounceRobotSessionURL](BounceRobotSessionURL.md), [RobotUA](RobotUA.md), [RobotIP](RobotIP.md),
[SourcePriority](SourcePriority.md), the [sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{BounceReferralsRobot}` in `lib/Vend/Dispatch.pm`.
