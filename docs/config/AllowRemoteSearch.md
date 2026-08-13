# AllowRemoteSearch

Whitelists the database tables that a search submitted from the browser is
allowed to target through the `mv_search_file` parameter. Reach for it to
control which tables are exposed to client-controlled searches.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    AllowRemoteSearch  table ...

A whitespace- or comma-separated list of table names that *replaces* the
current list (it does not accumulate). Default:
`products variants options`.

## Description

When a search request carries an `mv_search_file` value -- naming the
table(s) to search -- `lib/Vend/Page.pm` checks each requested file
against this list. If a requested table is not present, the search is
refused with a logged security violation and the request dies.

The default allows searches against `products`, `variants`, and
`options`, which are safe to expose. Any table you add here becomes
remotely searchable by anyone who can craft a search URL.

## Examples

Allow an extra catalog table to be searched from the browser (in
`catalog.cfg`):

```
AllowRemoteSearch products variants options articles
```

## Notes

Only expose tables that contain no sensitive data. A table listed here can
be searched with client-supplied criteria, so adding a table with customer
records, credentials, or internal fields would let those rows be probed
through ordinary search forms. Consider the exposure carefully before
extending the list.

## See also

[NoSearch](NoSearch.md), the [search](../guides/search.md) and
[security](../guides/security.md) guides.

## Source

Parsed by `parse_array_complete` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{AllowRemoteSearch}` in `lib/Vend/Page.pm`.
