# ProductFiles

Lists the database tables that together act as the catalog's logical
`products` database. Reach for it when products live in more than one table
and searches and lookups should span them all.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ProductFiles  table ...

A whitespace- or comma-separated list of table names that replaces the
current list (it is not additive). Default: `products`.

The alias `DefaultTables` sets the same directive.

## Description

Interchange treats the tables named here as one combined product source. The
first table in the list is the primary products table -- the default base for
searches and for item lookups when a cart item does not name its own table
(`$Vend::Cfg->{ProductFiles}[0]` in `lib/Vend/Cart.pm` and
`lib/Vend/DbSearch.pm`). A product search with no explicit table searches
every table in the list in turn, so items spread across several tables are
all found.

## Examples

Search two vendor tables as one product database (in `catalog.cfg`):

```
ProductFiles vendor_a vendor_b
```

The strap demo combines the base products table with its variants table:

```
ProductFiles products variants
```

## Notes

`DefaultTables` is an alias for this directive; the two names are
interchangeable.

## See also

[ProductDir](ProductDir.md), [AllowRemoteSearch](AllowRemoteSearch.md),
[Database](Database.md), the [databases](../guides/databases.md) and
[search](../guides/search.md) guides.

## Source

Parsed by `parse_array_complete` in `lib/Vend/Config.pm` (with
`DefaultTables` registered as an alias); consumed via
`$Vend::Cfg->{ProductFiles}` in `lib/Vend/Cart.pm`, `lib/Vend/DbSearch.pm`,
and the search code.
