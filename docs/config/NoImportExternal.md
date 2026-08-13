# NoImportExternal

Disables automatic import of external (SQL and LDAP) database tables from their
text source files. Reach for it when external tables are populated and
maintained outside Interchange and must not be reloaded from ASCII seed files.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    NoImportExternal  yes|no

A boolean (`parse_yesno`): `yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`.
Default: `No`.

## Description

Interchange classifies tables backed by an external engine -- currently SQL and
LDAP -- as "external" (their database class is marked `RestrictedImport`). When
`NoImportExternal` is enabled, the import routine in `lib/Vend/Data.pm` marks
every such table as no-import so its text source file is not read back into the
database:

```perl
if ($class_config->{RestrictedImport}) {
    ...
    if (
        $Vend::Cfg->{NoImportExternal}
        or -f $database_dbm
        or (! $obj->{CREATE_EMPTY_TXT} and ! -f $database_txt)
        )
    {
        $no_import = 1;
    }
}
```

This is the import counterpart of [NoExportExternal](NoExportExternal.md). It
applies to all external tables at once, whereas [NoImport](NoImport.md) names
individual tables of any type.

## Examples

Prevent auto-import of all external tables. In `catalog.cfg`:

```
NoImportExternal yes
```

## See also

[NoImport](NoImport.md), [NoExport](NoExport.md),
[NoExportExternal](NoExportExternal.md), [import](../tags/import.md), the
[databases](../guides/databases.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{NoImportExternal}` in the import routine of `lib/Vend/Data.pm`.
