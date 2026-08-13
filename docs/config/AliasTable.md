# AliasTable

Names a database table that maps requested page paths to the real pages
they should resolve to, letting you redirect or rewrite flypage-style URLs
without a filesystem lookup. Reach for it for content management and
pseudo-path schemes (short codes, campaign URLs, renamed pages).

**Scope:** catalog (`catalog.cfg`)

## Syntax

    AliasTable  table_name

A single table name. The value is stored as written (no parser). If page
aliasing is triggered but `AliasTable` is unset, Interchange defaults the
name to `alias`. Default: empty.

## Description

During dispatch, `lib/Vend/Dispatch.pm` looks up the current request path
(`$Vend::FinalPath`) in the named table. If a row is found, its
`real_page` column replaces the request path, so the alias is served as
that page. The lookup happens before Interchange reads a page file from
disk, so an alias can point to a page that need not exist under the
requested name.

Two further columns on the alias row are honored when present:

- `base_page` -- forces the flypage/base template used to render the
  result.
- `base_control` -- allows the row to seed CGI inputs for the request.

The table itself is an ordinary Interchange database; you define it with a
`Database` directive and then name it with `AliasTable`.

## Examples

Define the table and register it (in `catalog.cfg`):

```
Database alias alias.txt TAB
AliasTable alias
```

A tab-delimited `alias.txt` with columns `code` (key) and `real_page`
would then let the key `4595` redirect to `index`:

```
code	real_page
4595	index
```

## Notes

The `base_control` behavior (seeding CGI inputs from the alias row) is
present in the dispatch code but lightly documented; test your intended
use before relying on it.

## See also

[Database](Database.md), [RedirectCache](RedirectCache.md), the [catalog-anatomy](../guides/catalog-anatomy.md)
and [databases](../guides/databases.md) guides.

## Source

Stored unparsed in `lib/Vend/Config.pm` (no parse routine); consumed via
`$Vend::Cfg->{AliasTable}` in `lib/Vend/Dispatch.pm`.
