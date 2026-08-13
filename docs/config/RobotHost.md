# RobotHost

Lists hostname patterns that mark a visitor as a crawler (search-engine
robot) so Interchange can skip session overhead for it. Reach for it when
you want to classify bots by resolved hostname rather than by IP or user
agent.

**Scope:** global (`interchange.cfg`)

## Syntax

    RobotHost  PATTERN, PATTERN, ...

A whitespace/comma-separated list of DOS-style wildcard patterns
(`parse_list_wildcard_full`) compiled into a single fully anchored,
case-insensitive regular expression (`^(...)$`). In a pattern, `*` matches
any run of characters and `?` matches a single character; because the
expression is anchored, each pattern must match the whole hostname.
Default: empty.

## Description

For each request, Interchange resolves the client's hostname and tests it
against the compiled `RobotHost` expression. On a match it sets the
internal robot flag (`$Vend::Robot`) and serves a temporary session instead
of a full one, reducing crawler load and keeping session IDs out of indexed
URLs.

This test runs only when [HostnameLookups](HostnameLookups.md) is enabled,
since the reverse DNS lookup that produces `REMOTE_HOST` is otherwise not
performed. It is checked after [RobotIP](RobotIP.md) and before
[RobotUA](RobotUA.md), in `lib/Vend/Server.pm`.

As with the other robot directives, this only tunes session handling and
indexing; do not use it to serve crawlers different content.

## Examples

Enable hostname lookups and flag crawler domains (in `interchange.cfg`):

```
HostnameLookups Yes
RobotHost <<EOR
  *.googlebot.com,   *.crawl.yahoo.net,   *.search.msn.com,
  *.inktomisearch.com,
EOR
```

## Notes

Because the expression is fully anchored, a bare domain like `googlebot.com`
matches only that exact host; use a leading `*.` to match subdomains. See
the [robot](../glossary.md) glossary entry for background.

## See also

[RobotIP](RobotIP.md), [RobotUA](RobotUA.md),
[HostnameLookups](HostnameLookups.md), [RobotLimit](RobotLimit.md), the
[sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_list_wildcard_full` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm` (sets `$Vend::Robot`).
