# PageTables

Lists database tables that Interchange should consult for page content before
looking on disk. Reach for it to store pages in a database -- for example to
version pages or serve them by effective date -- instead of, or ahead of, the
file system.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    PageTables  table ...

A whitespace- or comma-separated list of table names that *replaces* the current
list (it does not accumulate). Default: empty (pages come only from
[PageDir](PageDir.md) and [TemplateDir](TemplateDir.md)).

## Description

When `PageTables` is set, `lib/Vend/Util.pm` tries to satisfy a page request from
those tables first. For each listed table it looks up a row keyed by the page
name and reads the page body from the column mapped to `page_text` by
[PageTableMap](PageTableMap.md). If a table yields content, that content is used;
otherwise Interchange falls through to the normal directory search
([PageDir](PageDir.md), [TemplateDir](TemplateDir.md)).

The lookup also supports a "teleport" mode: if the session carries a teleport
time, `teleport_name` selects the row whose `show_date`/`expiration_date` window
contains that time, letting you serve the version of a page that was effective at
a given moment. The columns those checks use are named through
[PageTableMap](PageTableMap.md).

## Examples

Serve pages from a `pages` database table, falling back to disk (in
`catalog.cfg`):

```
Database pages pages.txt TAB
PageTables pages
```

## Notes

This feature works with any SQL-capable table type. It is intended for database
back-ends; using it over a GDBM-style table is possible but rarely worthwhile.

## See also

[PageTableMap](PageTableMap.md), [PageDir](PageDir.md),
[TemplateDir](TemplateDir.md), [Database](Database.md), the
[templating](../guides/templating.md) and [databases](../guides/databases.md)
guides.

## Source

Parsed by `parse_array_complete` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{PageTables}` in `lib/Vend/Util.pm`.
