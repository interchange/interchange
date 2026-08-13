# NoExportExternal

Disables automatic re-export of external (SQL and LDAP) database tables back to
their text source files. Reach for it when your real data lives in an external
database and the text files are only a seed you do not want overwritten.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    NoExportExternal  yes|no

A boolean (`parse_yesno`): `yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`.
Default: `No`.

## Description

Interchange classifies tables backed by an external engine -- currently SQL and
LDAP -- as "external" (their database class is marked `RestrictedImport`). When
`NoExportExternal` is enabled, the export routine in `lib/Vend/Data.pm` skips
every such table:

```perl
if ($Vend::Cfg->{NoExportExternal} and !$opt->{force}) {
    # Skip export only for "external" tables (currently SQL and LDAP)
    my $class = $db->config('Class');
    my $class_config = $db_config{$class || $Global::Default_database};
    return 1 if $class_config->{RestrictedImport};
}
```

This is the export counterpart of [NoImportExternal](NoImportExternal.md). It
applies to all external tables at once, whereas [NoExport](NoExport.md) names
individual tables. An explicit [export](../tags/export.md) with `force=1` still
exports the table, and `[backup-database]` is not affected.

## Examples

Prevent auto-export of external tables, and additionally protect two named
tables. In `catalog.cfg`:

```
NoExportExternal yes
NoExport products inventory
```

## See also

[NoExport](NoExport.md), [NoImport](NoImport.md),
[NoImportExternal](NoImportExternal.md), [export](../tags/export.md), the
[databases](../guides/databases.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{NoExportExternal}` in the export routine of `lib/Vend/Data.pm`.
