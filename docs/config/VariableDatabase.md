# VariableDatabase

Loads Interchange [Variable](Variable.md) values from a database table
instead of from `Variable` lines in `catalog.cfg`. Reach for it when you
have many variables, or want non-programmers to edit them, and would rather
keep name/value pairs in a table than a long block of config directives.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    VariableDatabase  database_name

A single table name. Parsed by `parse_dbconfig`, which reads the table and
loads each row into the matching directive's hash. Default: empty.

## Description

`VariableDatabase` names a table whose key column holds variable names and
whose `Variable` column holds their values. `parse_dbconfig`
(`lib/Vend/Config.pm`) walks the table and, for the `Variable` column,
assigns each row into the catalog's `Variable` hash -- so a row keyed
`HELLO` with `Variable` value `Hi` is equivalent to `Variable HELLO Hi`.
The variables become available immediately, readable as `__NAME__` on pages
like any other catalog variable.

If no [Database](Database.md) directive has already defined the named table,
Interchange assumes a TAB-separated `.txt` file of the same name. That is:

```
VariableDatabase  variables
```

behaves like:

```
Database          variables  variables.txt  TAB
VariableDatabase  variables
```

To use a non-default source (a SQL table, a CSV file), define it with a
[Database](Database.md) directive *before* the `VariableDatabase` line.

## Examples

Save this as `products/variables.txt` (a TAB file with a `Variable`
column):

```
code	Variable
HELLO	Hi
ANON	Guest
```

Then, in `catalog.cfg`:

```
Database          variables  variables.txt  TAB
VariableDatabase  variables
```

On a page:

```
__HELLO__, __ANON__!
```

produces:

    Hi, Guest!

## Notes

You can list more than one `VariableDatabase` line to load variables from
several tables; later definitions override earlier variables of the same
name. The column name that supplies values must be `Variable` (matching the
directive name); the mechanism `parse_dbconfig` uses maps each table column
to the like-named directive.

## See also

[Variable](Variable.md), [Database](Database.md), [VarName](VarName.md),
[DirConfig](DirConfig.md), [DirectiveDatabase](DirectiveDatabase.md), the
[configuration](../guides/configuration.md) guide.

## Source

Parsed by `parse_dbconfig` in `lib/Vend/Config.pm`, which loads the table's
rows into the catalog `Variable` hash.
