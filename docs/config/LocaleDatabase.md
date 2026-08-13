# LocaleDatabase

Loads locale settings for a catalog from a database table instead of (or in
addition to) inline [Locale](Locale.md) directives. Reach for it to keep
your translations and locale-specific values in an editable table rather
than in `catalog.cfg`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    LocaleDatabase  TABLE

Names an already-defined Interchange [Database](Database.md) table.
Default: empty (no database-backed locales).

## Description

`LocaleDatabase` reads a table whose layout is column-per-locale: the first
column is a key, and each remaining column header names a locale. For every
row, the value in a locale's column becomes the value of that key in the
locale's repository. In effect each column is one locale's set of
[Locale](Locale.md) key/value pairs.

Settings loaded this way are merged on top of any locales already defined
by [Locale](Locale.md) directives -- database values add to and override
the inline ones. The referenced table must be defined (via
[Database](Database.md)) before `LocaleDatabase` runs.

The directive is processed at catalog configuration time.

## Examples

Define the table, then load locales from it (from the strap demo, which
uses a `locale` table):

```
Database locale locale.asc TAB
LocaleDatabase locale
```

A tab-delimited `locale` table looks like this -- the header row names the
locales, each data row is one key:

```
code    en_US   en_GB   fr_FR   de_DE   nl_NL
color   color   colour  couleur Farbe   kleur
```

## Notes

`LocaleDatabase` shares its parser with [Route](Route.md)'s
`RouteDatabase` and similar directives (`parse_configdb`): the `Database`
suffix is stripped to find the repository name, so `LocaleDatabase`
populates the `Locale` repository.

## See also

[Locale](Locale.md), [Database](Database.md),
[DefaultLocale](DefaultLocale.md), the
[internationalization](../guides/internationalization.md) guide.

## Source

Parsed by `parse_configdb` in `lib/Vend/Config.pm`, which reads the named
table into the catalog's `Locale_repository`.
