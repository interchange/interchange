# MoreDBTable

Names the database table used to store search paging data when
[MoreDB](MoreDB.md) is enabled. Reach for it to keep the "more" paging data in
a table other than the session table.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    MoreDBTable  tablename

A table name, stored verbatim (no parser is run). Default: empty (the
[SessionDB](SessionDB.md) table is used).

## Description

`MoreDBTable` has effect only when [MoreDB](MoreDB.md) is on. In that mode,
Interchange stores and retrieves search "more" paging data through a database
handle obtained in `lib/Vend/Search.pm`:

```perl
my $db = Vend::Util::dbref($Vend::Cfg->{MoreDBTable} || $Vend::Cfg->{SessionDB});
```

If `MoreDBTable` names a table, that table holds the paging data; otherwise the
[SessionDB](SessionDB.md) table is used. The paging record is stored in a
`session` column keyed by the search cache id, so the target table must provide
that structure -- the same layout as the session table.

## Examples

Store paging data in a dedicated table rather than the session table. In
`catalog.cfg`:

```
MoreDB      Yes
MoreDBTable more_paging
```

## See also

[MoreDB](MoreDB.md), [SessionDB](SessionDB.md), [SessionType](SessionType.md),
the [search](../guides/search.md) guide.

## Source

Stored unparsed (no `parse_*` routine) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{MoreDBTable}` in `lib/Vend/Search.pm`.
