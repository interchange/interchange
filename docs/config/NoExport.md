# NoExport

Names database tables that Interchange must never automatically re-export to
their text source files. Reach for it to protect tables whose authoritative
data lives in the database, not in the text file.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    NoExport  table ...

A whitespace- or comma-separated list of table names (`parse_boolean`), each
recorded as a key of a hash. The directive accumulates across lines. Default:
empty (no table is protected from export).

## Description

Interchange can write a table's contents back out to its ASCII source file --
for example when a table is modified and later exported. A table named in
`NoExport` is skipped by the export routine in `lib/Vend/Data.pm`:

```perl
return 1 if $Vend::Cfg->{NoExport}{$table_name} and !$opt->{force};
```

The value is stored as a hash keyed by table name, so `NoExport` acts as a
per-table on/off flag. This prevents automatic exports from overwriting the
text source of a table you maintain directly in the database.

Two escape hatches remain: an explicit [export](../tags/export.md) with
`force=1` still exports the table, and `[backup-database]` is not affected by
this setting.

Unlike [NoExportExternal](NoExportExternal.md) (which applies to all external
SQL/LDAP tables at once), `NoExport` targets specific named tables of any type.

## Examples

Never auto-export the `products` and `inventory` tables. In `catalog.cfg`:

```
NoExport products inventory
```

## See also

[NoExportExternal](NoExportExternal.md), [NoImport](NoImport.md),
[NoImportExternal](NoImportExternal.md), [export](../tags/export.md), the
[databases](../guides/databases.md) guide.

## Source

Parsed by `parse_boolean` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{NoExport}` in the export routine of `lib/Vend/Data.pm`.
