# RobotUA

Lists user-agent patterns that mark a visitor as a crawler (search-engine
robot) so Interchange can skip session overhead for it. Reach for it to
keep bots from consuming sessions and to serve them clean, indexable URLs.

**Scope:** global (`interchange.cfg`)

## Syntax

    RobotUA  PATTERN, PATTERN, ...

A whitespace/comma-separated list of DOS-style wildcard patterns
(`parse_list_wildcard`) compiled into a single case-insensitive regular
expression. In a pattern, `*` matches any run of characters and `?`
matches a single character. The patterns match anywhere within the
user-agent string (not anchored). Default: empty.

## Description

For each request, Interchange tests the browser's `User-Agent` header
against the compiled `RobotUA` expression. On a match it sets the internal
robot flag (`$Vend::Robot`), which causes it to use a temporary session
rather than allocating and tracking a full one. This reduces load from
crawlers and keeps session IDs out of the URLs a crawler indexes.

The user-agent test is checked only after the [RobotIP](RobotIP.md) and
[RobotHost](RobotHost.md) tests; a user agent matching
[NotRobotUA](NotRobotUA.md) is exempted before `RobotUA` is consulted. The
match is performed in `lib/Vend/Server.pm`.

Robot detection is meant only to reduce overhead and improve indexing.
Tailoring page *content* to detected crawlers ("cloaking") gains nothing
and may be penalized by the search engine.

## Examples

Flag a handful of well-known crawlers:

```
RobotUA  Googlebot, Slurp, bingbot, DuckDuckBot
```

A longer list is easier to maintain in a here-document:

```
RobotUA <<EOR
    AltaVista, Ask, Atomz, Excite, Google, Lycos, Scooter, Slurp,
    Spyder, Yahoo, Yandex, bot, crawl, spider, archiver, wget,
EOR
```

## Notes

Because patterns match as substrings, a short pattern like `bot` matches
any agent containing that sequence. See the [robot](../glossary.md)
glossary entry for background on how Interchange handles crawlers.

## See also

[RobotIP](RobotIP.md), [RobotHost](RobotHost.md),
[NotRobotUA](NotRobotUA.md), [RobotLimit](RobotLimit.md), the
[sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_list_wildcard` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm` (sets `$Vend::Robot`).
