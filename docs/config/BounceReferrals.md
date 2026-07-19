# BounceReferrals

Redirects an incoming GET request that carries an affiliate/source code to
the same URL with the code removed, so the visible URL is clean after the
first hit. Reach for it when you use affiliate tracking and want search
engines to index one canonical URL per page instead of many code-salted
variants.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    BounceReferrals  Yes|No

A yes/no boolean (`yes`/`no`, `true`/`false`, `1`/`0`, `on`/`off`,
case-insensitive). Default: `No`.

## Description

Interchange records an affiliate code from the `mv_pc` or `mv_source`
parameter (see `SourcePriority`) into the session. When `BounceReferrals`
is on and a GET request arrives with a new source code, the dispatch code
in `lib/Vend/Dispatch.pm` issues a `301 Moved` redirect to the same path
with the code stripped from the query string. The source is already saved
in the session, so tracking is not lost.

This keeps redirect-respecting search engines from storing the
code-salted URLs, focusing them on a single canonical URL per resource.

## Examples

Enable referral bouncing (in `catalog.cfg`):

```
BounceReferrals yes
```

## Notes

On a visitor's very first access they usually have no session cookie yet,
so the bounced URL will still carry the session ID even though the
affiliate code is gone. Interchange treats session IDs in URLs as a
separate concern from the affiliate-code stripping this directive
performs; if URL session IDs matter to you, address them separately.

`BounceReferralsRobot` applies the same stripping but only to requests
identified as robots; `BounceRobotSessionURL` strips an explicit session
ID from robot requests.

## See also

[BounceReferralsRobot](BounceReferralsRobot.md), [BounceRobotSessionURL](BounceRobotSessionURL.md), [SourcePriority](SourcePriority.md),
[SourceCookie](SourceCookie.md), [RobotUA](RobotUA.md), the [sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{BounceReferrals}` in `lib/Vend/Dispatch.pm`.
