# ConfigDatabase

Points Interchange at a database table whose rows supply configuration
directives that would otherwise live in `catalog.cfg`. Reach for it to store
and manage a catalog's directive settings in a database.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

> **Note:** although this directive is defined for both scopes, the loading of
> its rows is only implemented at catalog scope (see Notes).

## Syntax

    ConfigDatabase  name  source_file  type

    ConfigDatabase  name  PARAM  value

- `name` -- an identifier for the config database.
- `source_file` -- the table's data file.
- `type` -- the table type (for example `dbi:mysql:config`, `TAB`, `CSV`,
  `PIPE`, `DEFAULT`, or a numeric type code).

The second form sets a parameter of an already-named config database. The
special parameter `LOAD 1` fills the database with the initial values from your
`catalog.cfg` on the next restart; remove it once loaded. Default: empty.

## Description

The named table holds directive definitions in rows -- typically columns for a
record code, the directive name, its value, and an extended value. When the
catalog is configured, Interchange reads those rows and applies them exactly as
if the directives had appeared in `catalog.cfg`.

The table is expected to have columns along these lines:

```sql
create table config (
  code      varchar(32) NOT NULL PRIMARY KEY,
  directive varchar(64) NOT NULL,
  value     varchar(255),
  extended  text
);
```

## Examples

Define a config database and load its initial data from `catalog.cfg` (in
`catalog.cfg`):

```
ConfigDatabase config config.txt dbi:mysql:config
ConfigDatabase config LOAD 1
```

Given the table above, rows of:

```
code|directive|value|extended
C0001|VariableDatabase|variable
C0002|SessionExpire|2 hours|
C0003|Variable|foo|   bar
```

correspond to the `catalog.cfg` definitions:

```
VariableDatabase variable
SessionExpire  2 hours
Variable foo <<EOF
   bar
EOF
```

## Notes

Although `ConfigDatabase` appears in both the global and catalog directive
tables and its parser stores a global value, only the catalog-scope value is
ever read and applied -- the config-loading code consults
`$C->{ConfigDatabase}` only. In practice, use it in `catalog.cfg`; a global
`ConfigDatabase` line has no loading effect.

## See also

[DirectiveDatabase](DirectiveDatabase.md), [VariableDatabase](VariableDatabase.md),
[Database](Database.md), [Variable](Variable.md), the
[databases](../guides/databases.md) and
[configuration](../guides/configuration.md) guides.

## Source

Parsed by `parse_config_db` in `lib/Vend/Config.pm`; loaded from the table by
the catalog-config code (`$C->{ConfigDatabase}`) in `lib/Vend/Config.pm`.
