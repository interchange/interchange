# NoImport

Names database tables that Interchange must never automatically import from
their text source files. Reach for it to protect tables whose live data must
not be overwritten by a stale ASCII file.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    NoImport  table ...

A whitespace- or comma-separated list of table names (`parse_boolean`), each
recorded as a key of a hash. The directive accumulates across lines. Default:
empty (no table is protected from import).

## Description

Interchange normally (re)imports a table from its text source file when the
source is newer than the database copy, at catalog startup or when the file
changes. A table listed in `NoImport` is exempted: the import routine in
`lib/Vend/Data.pm` treats it as no-import:

```perl
my $no_import = defined $Vend::Cfg->{NoImport}->{$name} || $obj->{NO_IMPORT};
```

The value is stored as a hash keyed by table name. This keeps a table's live
contents from being replaced by the text file. Import is still performed if the
database completely disappears (there is nothing to preserve), and a forced
import (`$Vend::ForceImport`) overrides the flag.

Unlike [NoImportExternal](NoImportExternal.md) (which applies to all external
SQL/LDAP tables at once), `NoImport` targets specific named tables of any type.

## Examples

Never auto-import the `products` and `inventory` tables. In `catalog.cfg`:

```
NoImport products inventory
```

## See also

[NoImportExternal](NoImportExternal.md), [NoExport](NoExport.md),
[NoExportExternal](NoExportExternal.md), [import](../tags/import.md), the
[databases](../guides/databases.md) guide.

## Source

Parsed by `parse_boolean` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{NoImport}` in the import routine of `lib/Vend/Data.pm`.
