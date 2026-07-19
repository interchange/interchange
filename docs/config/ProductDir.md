# ProductDir

Names the directory that holds the catalog's database source and data files.
Reach for it to keep product and other table files somewhere other than the
default `products` directory.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ProductDir  directory

A single relative directory, resolved against the catalog root. An absolute
path is rejected unless [NoAbsolute](NoAbsolute.md) is turned off. Default:
`products`.

The alias `DataDir` sets the same directive.

## Description

Interchange looks in `ProductDir` for the source files behind its database
tables (the `.txt`/`.asc` files and, by default, the DBM or table data) and
for related data such as the sales-tax file. Various table and search
routines consult `$Vend::Cfg->{ProductDir}` -- for example in
`lib/Vend/Data.pm`, `lib/Vend/Scan.pm`, and `lib/Vend/Glimpse.pm` -- and
fall back to it when a table does not specify its own directory.

The value is taken relative to the catalog root. It may be an absolute path
only when [NoAbsolute](NoAbsolute.md) has been disabled.

## Examples

Keep data files in a `databases` directory (in `catalog.cfg`):

```
ProductDir databases
```

Use an absolute location (requires `NoAbsolute` off):

```
NoAbsolute 0

ProductDir /data/catalog/for-sale
```

## Notes

`DataDir` is an alias for this directive; the two names are interchangeable.

## See also

[ProductFiles](ProductFiles.md), [PageDir](PageDir.md),
[NoAbsolute](NoAbsolute.md), [Database](Database.md), the
[databases](../guides/databases.md) guide.

## Source

Parsed by `parse_relative_dir` in `lib/Vend/Config.pm` (with `DataDir`
registered as an alias); consumed via `$Vend::Cfg->{ProductDir}` in
`lib/Vend/Data.pm`, `lib/Vend/Scan.pm`, and `lib/Vend/Glimpse.pm`.
