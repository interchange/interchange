# ExecutionLocale

Sets the base system locale that Interchange re-applies on every page, so the
daemon can never be left running under an unexpected locale. Reach for it only
if the default `C` locale causes problems for your platform's low-level
operations.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ExecutionLocale  locale_name

The raw value is stored as a string (no parser is run). Give a system locale
name such as `C` or `de_DE`. Default: `C`.

## Description

Interchange can switch locales while running to format currency, dates, and
sorting for a visitor. `ExecutionLocale` defines the "lowest-level" locale that
is reset at the start of processing each page (`POSIX::setlocale(LC_ALL, ...)`
in `lib/Vend/Dispatch.pm`), guaranteeing a known baseline before any
per-request locale changes are applied. Temporary locale changes for specific
code sections are made and reverted as needed; the majority of code runs under
this base locale.

## Examples

Keep the default (rarely changed) in `catalog.cfg`:

```
ExecutionLocale C
```

Set the base locale to German:

```
ExecutionLocale de_DE
```

## Notes

Most catalogs never need to change this. The base locale should be one whose
numeric and collation behavior your code expects; `C` avoids locale-dependent
surprises in low-level operations. Per-visitor formatting is handled through
[Locale](Locale.md), not this directive.

## See also

[Locale](Locale.md), [DefaultLocale](DefaultLocale.md), the
[internationalization](../guides/internationalization.md) guide.

## Source

Stored as a raw string (no parser) from `catalog_directives()` in
`lib/Vend/Config.pm`; consumed in `lib/Vend/Dispatch.pm`
(`$Vend::Cfg->{ExecutionLocale}`).
