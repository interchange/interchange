# TableRestrict

Restricts database searches on a table to rows whose named column matches a
value from the current session, emulating per-user database "views." Reach for
it when several users share one table but each may see only their own rows.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    TableRestrict  table  field=sessionkey

A whitespace-separated set of `key value` pairs, where the key is a table name
and the value is a `field=sessionkey` restriction. `field` is a column in that
table; `sessionkey` is a key in the current session hash (for example
`username`, the logged-in user name). The directive accumulates into a hash, so
multiple lines add restrictions for additional tables. Default: empty (no table
is restricted).

## Description

When a table has a `TableRestrict` entry, every database search against it gains
an extra condition so that only rows where `field` equals the session value of
`sessionkey` are returned. For an SQL table the search

```sql
SELECT * FROM products
```

effectively becomes

```sql
SELECT * FROM products WHERE owner = '[data session username]'
```

The comparison uses the top-level session value `$Vend::Session->{sessionkey}`.
The restriction is bypassed for a superuser when a `$Global::SuperUserFunction`
is defined and returns true, so administrative searches still see every row.

Because the value lives in `$Vend::Cfg->{TableRestrict}`, embedded Perl can set
it for the duration of a single page and Interchange restores the configured
value on the next request.

## Examples

Restrict `products` searches to rows the current user owns
(in `catalog.cfg`):

```
TableRestrict  products  owner=username
```

A record is returned only when its `owner` column matches
`[data session username]`.

Set the restriction temporarily from embedded Perl on one page:

```
[calc]
    # Restrict edit to owned rows for this page only
    $Config->{TableRestrict}{products} = 'owner=username';
    return;
[/calc]
```

## Notes

`TableRestrict` filters database (field) searches only; it does not affect text
searches. It is useful in mall situations where a store may see only products
carrying its own store ID.

## See also

[NoSearch](NoSearch.md), [AllowRemoteSearch](AllowRemoteSearch.md), the
[search](../guides/search.md) and [databases](../guides/databases.md) guides.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Table/DBI.pm` (SQL tables) and `lib/Vend/Table/Common.pm`
(non-SQL tables) via `$Vend::Cfg->{TableRestrict}`.
