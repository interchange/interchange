# AcrossLocks

Forces every configured database to be opened for real at the start of
each page request, instead of Interchange's default of handing out a fast
placeholder and opening the table only when it is first used. Reach for it
only in the rare case where the deferred-open behavior causes trouble.

**Scope:** global (`interchange.cfg`)

## Syntax

    AcrossLocks  Yes|No

A yes/no boolean (`yes`/`no`, `true`/`false`, `1`/`0`, `on`/`off`,
case-insensitive). Default: `No`.

## Description

By default, when a page begins processing Interchange does not open a live
connection to every configured database. Opening a connection costs time,
so it substitutes a lightweight placeholder for each table and only ties
the real database when the table is actually referenced on the page.

Setting `AcrossLocks` disables those placeholders: every configured
database is tied (opened) at the point the request acquires its locks,
whether or not the page ends up using it.

The flag is read once at startup and consulted in `lib/Vend/Data.pm` when
deciding whether to tie a database eagerly.

## Examples

Open all databases on every request in `interchange.cfg`:

```
AcrossLocks Yes
```

## Notes

Leaving this off is almost always correct; the placeholder mechanism is a
performance optimization. Turn it on only if you have code that depends on
a table connection existing before the table is first referenced.

## See also

[HotDBI](HotDBI.md), the [databases](../guides/databases.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Global::AcrossLocks` in `lib/Vend/Data.pm`.
