# MoreDB

Stores search "more" paging data in a database session table instead of files
in the scratch directory. Reach for it when running multiple Interchange nodes
that must share paged search results without a shared filesystem.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    MoreDB  yes|no

A boolean (`parse_yesno`): `yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`.
Default: `No`.

## Description

When a search returns more matches than a page shows, Interchange saves the
result set so the "next"/"previous" (more) links can page through it without
re-running the search. By default this data is written to files under
[ScratchDir](ScratchDir.md). When `MoreDB` is enabled, the paging data is
stored in a database table instead, keyed by the search's cache id. The code
in `lib/Vend/Search.pm` reads and writes the data through a database handle:

```perl
if($Vend::Cfg->{MoreDB}) {
    my $db = Vend::Util::dbref($Vend::Cfg->{MoreDBTable} || $Vend::Cfg->{SessionDB});
    ...
}
```

The table used is [MoreDBTable](MoreDBTable.md) if set, otherwise the
[SessionDB](SessionDB.md) table. Storing paging data in the database removes
the need for a shared [ScratchDir](ScratchDir.md) across nodes.

## Examples

Store paging data in the session database. In `catalog.cfg`:

```
SessionType DBI
SessionDB   session

MoreDB Yes
```

## Notes

`MoreDB` relies on a database-backed session store. Enabling it with a
non-database session type has no valid table to write to and produces errors;
set [SessionType](SessionType.md) and [SessionDB](SessionDB.md) (or
[MoreDBTable](MoreDBTable.md)) accordingly.

## See also

[MoreDBTable](MoreDBTable.md), [SessionDB](SessionDB.md),
[SessionType](SessionType.md), [ScratchDir](ScratchDir.md), the
[search](../guides/search.md) and [sessions](../guides/sessions.md) guides.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{MoreDB}` in `lib/Vend/Search.pm`.
