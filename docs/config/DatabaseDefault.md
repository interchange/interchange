# DatabaseDefault

Sets default parameters applied to every [Database](Database.md) table
defined afterward, so you write shared settings (such as SQL credentials)
once instead of repeating them per table. Reach for it in catalogs where
many tables share the same connection or options.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    DatabaseDefault  PARAMETER  value

A hash (`parse_hash`) of parameter/value pairs; multiple lines accumulate,
and a here-document may set several at once. Each parameter is one of the
scalar attributes a [Database](Database.md) line accepts. Default: empty.

## Description

When a [Database](Database.md) table is first defined, Interchange folds
in the current `DatabaseDefault` values as that table's starting
attributes. An explicit parameter on the table's own `Database` line
overrides the default. This makes it the natural home for connection
settings shared by all of a catalog's SQL tables -- `USER`, `PASS`,
and similar.

`DatabaseDefault` accepts scalar parameters only. Structured attributes
that take per-column or repeated values are not defaultable this way,
including `COLUMN_DEF`, `NAME`, `NUMERIC`, `BINARY`, `DEFAULT`,
`FIELD_ALIAS`, `POSTCREATE`, `WRITE_CATALOG`, and the `ALTERNATE_*` and
`FILTER_*` families.

## Examples

Set a default SQL username and password for every table that follows:

```
DatabaseDefault USER interchange
DatabaseDefault PASS nevairbe
```

Set several defaults at once with a here-document:

```
DatabaseDefault <<EOD
  WRITE_CONTROL   1
  WRITE_TAGGED    1
  HIDE_AUTO_FILES 1
EOD
```

Keep database errors out of the shopper's session log:

```
DatabaseDefault LOG_ERROR_SESSION 0
```

## Notes

Defaults take effect only for tables defined *after* the
`DatabaseDefault` line, so place these directives before the
[Database](Database.md) lines they should govern. To wipe accumulated
defaults (for example in a subcatalog), use
`Replace DatabaseDefault` -- see [Replace](Replace.md).

## See also

[Database](Database.md), [DatabaseAuto](DatabaseAuto.md),
[Replace](Replace.md), the [databases](../guides/databases.md) guide.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm`; consumed via
`$C->{DatabaseDefault}` when tables are defined in `parse_database`
(`lib/Vend/Config.pm`).
