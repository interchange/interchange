# RobotIP

Lists IP addresses, ranges, or patterns that mark a visitor as a crawler
(search-engine robot) so Interchange can skip session overhead for it.
Reach for it when you want to classify bots by source address rather than
by user agent.

**Scope:** global (`interchange.cfg`)

## Syntax

    RobotIP  ENTRY, ENTRY, ...

A comma-separated list of entries (`parse_list_wildcard_cidr`) compiled
into a single anchored, case-insensitive regular expression. Each entry may
be a CIDR block (`208.146.26.0/24`), an IPv6 address, or a DOS-style
wildcard (`*` for any run of characters, `?` for a single character).
Default: empty.

## Description

For each request, Interchange tests the client's remote address
(`REMOTE_ADDR`) against the compiled `RobotIP` expression. On a match it
sets the internal robot flag (`$Vend::Robot`) and serves the request with a
temporary session instead of a full, tracked one, reducing crawler load and
keeping session IDs out of indexed URLs.

The IP test is checked first, before the [RobotHost](RobotHost.md) and
[RobotUA](RobotUA.md) tests. The match is performed in
`lib/Vend/Server.pm`.

As with the other robot directives, this only tunes session handling and
indexing; do not use it to serve crawlers different content.

## Examples

Flag two subnets and a single address:

```
RobotIP  66.249.64.0/19, 208.146.26.0/24, 216.35.103.6?
```

A longer list in a here-document:

```
RobotIP <<EOR
  202.9.155.123,   204.152.191.41,   208.146.26.0/24,
  209.185.141.0/24,  216.35.103.*,
EOR
```

## Notes

CIDR and IPv6 entries are recognized and converted to address-range
regexes; entries that are neither are treated as wildcard patterns. See the
[robot](../glossary.md) glossary entry for background.

## See also

[RobotUA](RobotUA.md), [RobotHost](RobotHost.md),
[RobotLimit](RobotLimit.md), [TrustProxy](TrustProxy.md), the
[sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_list_wildcard_cidr` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm` (sets `$Vend::Robot`).
