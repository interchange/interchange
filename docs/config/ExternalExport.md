# ExternalExport

Selects which Perl values Interchange writes to the external structure file when
[External](External.md) export is enabled. Reach for it to control exactly what
global and catalog data external programs can see.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    ExternalExport  item ...

The raw value is stored as a string (no parser is run); items are separated by
whitespace or commas (a heredoc is convenient for long lists). The item syntax
differs by scope.

### Global

    ExternalExport  Interchange::Object=Output_name ...

Each item names a Perl package variable to export, optionally renamed for the
output file with `=`. Bare names default to the `Global::` package. The `->`
notation walks into a hash or array to export a single element. Global values
appear directly under each catalog's hash in the output file. Default:
`Global::Catalog=Catalog`.

### Catalog

    ExternalExport  Object[->key_or_index] ...

Each item names a catalog configuration value; renaming with `=` is not
available, but `->` selects a specific hash key or array index. Catalog values
appear under the `external_config` key of each catalog's hash in the output
file. Default: a built-in list of common catalog values (`CatalogName`,
`ScratchDefault`, `ValuesDefault`, `ScratchDir`, `SessionDB`,
`SessionDatabase`, `SessionExpire`, `VendRoot`, `VendURL`, `SecureURL`, and the
`SQLDSN`/`SQLPASS`/`SQLUSER` variables).

## Description

At catalog configuration time (with [External](External.md) enabled), the global
export set builds the shared portion of the structure and the catalog export set
builds that catalog's `external_config` block; the combined result is written to
[ExternalFile](ExternalFile.md) (`external_global` and `external_cat` in
`lib/Vend/Config.pm`).

## Examples

In `interchange.cfg`, export the catalog count under a custom name:

```
External yes
ExternalExport Global::Catalog=number_of_catalogs
ExternalFile /tmp/external
```

In `catalog.cfg`, export selected catalog values and specific variables:

```
External yes
ExternalExport <<EOD
  CatalogName
  VendURL
  SecureURL
  SessionExpire
  Variable->SQLDSN
  Variable->SQLUSER
EOD
```

## Notes

Referencing a key that is not a hash or array element where the syntax expects
one raises a configuration error, so keep the `->` paths aligned with the actual
structure. Only meaningful data should be exported; the file is readable by any
process that can open it.

## See also

[External](External.md), [ExternalFile](ExternalFile.md),
[Variable](Variable.md), the [sessions](../guides/sessions.md) guide.

## Source

Stored as a raw string (no parser) from both directive tables in
`lib/Vend/Config.pm`; consumed by `external_global` and `external_cat` in
`lib/Vend/Config.pm`.
