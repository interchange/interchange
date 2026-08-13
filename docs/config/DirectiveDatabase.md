# DirectiveDatabase

Loads catalog configuration directives from a database table at config
time, letting a table row supply values that would otherwise be written
in `catalog.cfg`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    DirectiveDatabase  table

The named table must already be declared with
[Database](Database.md). Default: empty (no directive database).

## Description

Parsed by `parse_dbconfig` in `lib/Vend/Config.pm` — the same mechanism
behind [VariableDatabase](VariableDatabase.md) and
[RouteDatabase](RouteDatabase.md). Each column of the table names a
directive; hash-type directives already present in the configuration are
merged with the table's per-row values. Columns that do not match a known
directive are collected but ignored as directives. The table is read once
during catalog configuration; changing it requires a
[reconfiguration](../guides/configuration.md).

## Examples

In `catalog.cfg`:

    Database           dirconf  dirconf.txt  TAB
    DirectiveDatabase  dirconf

## Notes

This directive was absent from the historic manuals; it is documented
here from the parser source. Test the merge behavior for the specific
directives you intend to drive from a table before relying on it.

## See also

[VariableDatabase](VariableDatabase.md), [RouteDatabase](RouteDatabase.md),
[ConfigDatabase](ConfigDatabase.md), [Database](Database.md)

## Source

Parsed by `parse_dbconfig` in `lib/Vend/Config.pm` (directive table entry
at line ~628).
