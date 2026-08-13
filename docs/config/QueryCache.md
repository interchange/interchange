# QueryCache

Configures the query cache, a facility that stores the results of selected
searches in a database table and serves them back over a lightweight URL
(typically for AJAX callers) without building a full session. Reach for it
when you want repeated, public query results to be answered cheaply.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    QueryCache  key value  key value ...

A set of `key value` pairs (`parse_hash`) merged into a hash. Recognized
keys are `table`, `intro`, `default_expire`, `default_public_expire`, and
`default_return`. Default: empty; but once any value is set, Interchange
fills in the following defaults during configuration:

| Key                     | Default     | Meaning                              |
|-------------------------|-------------|--------------------------------------|
| `table`                 | `qc`        | Database table holding cached results|
| `intro`                 | `qc`        | First path segment that triggers a cache lookup |
| `default_expire`        | `30min`     | Lifetime of a private cached entry   |
| `default_public_expire` | `48hours`   | Lifetime of a public cached entry    |
| `default_return`        | `{}`        | Value returned on a miss             |

## Description

When `QueryCache` is set, Interchange watches incoming request paths. A
request whose path begins with `/<intro>/` (for example `/qc/...` with the
default `intro`) is intercepted very early in dispatch, before a normal
session is established, and answered directly from the query-cache table
rather than by rendering a page. This keeps cheap, repeatable lookups --
the kind an AJAX widget fires -- off the full page-serving path.

The hash is consumed in `lib/Vend/Dispatch.pm`, which matches the request
path against `intro` and calls `Vend::Data::run_query_cache`; that routine
uses `table` for storage and the `default_expire` /
`default_public_expire` values to decide when a stored result is stale.

## Examples

Enable the query cache with all defaults:

```
QueryCache table qc
```

Use a custom table and path prefix, and keep public results for a day:

```
QueryCache table querycache  intro ajaxq  default_public_expire 24hours
```

A request to `/ajaxq/...` is then answered from the `querycache` table.

## Notes

The intercept happens before session setup, so a query-cache URL does not
create or consume a session. Access is gated by `$Vend::allow_qc`, which
Interchange sets when it recognizes a returning cookie; this limits which
callers may reach public cached queries.

## See also

[SessionExpire](SessionExpire.md), [Database](Database.md),
[RedirectCache](RedirectCache.md), the
[databases](../guides/databases.md) and [search](../guides/search.md)
guides.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm` (defaults applied in the
`QueryCache` postprocess routine there); consumed in `lib/Vend/Dispatch.pm`
via `Vend::Data::run_query_cache`.
