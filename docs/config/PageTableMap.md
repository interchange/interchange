# PageTableMap

Maps the logical field names Interchange uses when reading pages from a database
to the actual column names in your [PageTables](PageTables.md) tables. Reach for
it only when those columns are not already named the way Interchange expects.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    PageTableMap  logical_name column  logical_name column ...

Whitespace-separated `key value` pairs forming a hash. Each key is a logical
field Interchange looks for; each value is the column in your page table that
supplies it. Default (each field mapped to a column of the same name):

    code            code
    base_page       base_page
    show_date       show_date
    expiration_date expiration_date
    page_text       page_text

## Description

When [PageTables](PageTables.md) is set, `lib/Vend/Util.pm` reads page content
and date-window information through this map rather than referring to column
names directly. `page_text` names the column holding the page body; `show_date`
and `expiration_date` name the columns that bound a page's effective period for
teleport (point-in-time) retrieval; `code` and `base_page` identify the page and
its base version.

The default maps every logical name to an identically named column, so you only
need `PageTableMap` if your table uses different column names. The [admin
UI](../guides/admin-ui.md) does not necessarily honor a remapping, so keeping the
default names is generally simpler.

## Examples

Read the page body from a `body` column and the effective dates from `starts`
and `ends` (in `catalog.cfg`):

```
PageTableMap page_text body  show_date starts  expiration_date ends
```

Unlisted logical names keep their default (same-named) mapping.

## See also

[PageTables](PageTables.md), [PageDir](PageDir.md), the
[templating](../guides/templating.md) guide.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{PageTableMap}` in `lib/Vend/Util.pm`.
