# NoSearch

Names the database tables (or file names) that Interchange-style searches are
not allowed to run against. Reach for it to keep sensitive tables such as the
user database out of reach of ordinary search requests.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    NoSearch  wildcard

A single DOS-style wildcard pattern (`*`, `?`, `{a,b}`) that is compiled to a
regular expression. Space-separated tokens in the value become alternatives, so
you may list several patterns on one line. Default: `userdb`.

## Description

Before Interchange runs a search it collects the tables (or search files) the
request wants to search. Each candidate name is matched against the compiled
`NoSearch` pattern in `lib/Vend/Scan.pm`; any name that matches is dropped and
the refusal is logged:

    Search of 'userdb' denied by NoSearch directive

The default, `userdb`, blocks searches of the user database so that customer
login records cannot be probed through a search form. The check applies to
Interchange's own file- and database-backed searches. It does not restrict
searches performed by passing raw SQL to a table.

Because the value is compiled from your line at configuration time, you can widen
it to cover naming conventions -- for example any table beginning with a dot or
ending in a chosen suffix.

## Examples

Block the user database plus any table beginning with `.` or ending in
`.secret` (in `catalog.cfg`):

```
NoSearch userdb .* *.secret
```

Turn the restriction off for a single page, without changing the catalog
default, by clearing the runtime value in Interchange Tag Language (ITL):

```
[calc]$Config->{NoSearch} = ''; return;[/calc]
```

## Notes

`NoSearch` only governs Interchange's own search machinery. A page that issues a
raw SQL query with the [query](../tags/query.md) tag is not affected, so do not
rely on it as the only guard for a sensitive table.

## See also

[AllowRemoteSearch](AllowRemoteSearch.md), the
[search](../guides/search.md) and [security](../guides/security.md) guides.

## Source

Parsed by `parse_wildcard` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{NoSearch}` in `lib/Vend/Scan.pm`.
