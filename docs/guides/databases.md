# Databases

Interchange puts a uniform data layer over very different storage: flat
text files imported into DBM tables, and real SQL databases (MySQL,
PostgreSQL, SQLite, anything with a DBD driver). Pages address both the
same way — `[data table column key]` — and a catalog can mix them freely.
This chapter explains the [Database](../config/Database.md) declaration
model, the flat-file/table relationship, the backends, and how data is
read, written, imported, and exported. Searching over these tables is
covered in [The search engine](search.md).

## Declaring a table

Every table the catalog uses is declared in configuration — strap keeps
one file per table under `dbconf/<engine>/`
([Catalog anatomy](catalog-anatomy.md)). The pattern, abbreviated from
`dist/strap/dbconf/mysql/products.mysql`:

    Database  products  products.txt  __SQLDSN__
    Database  products  KEY           sku
    Database  products  COLUMN_DEF    "sku=char(64) NOT NULL PRIMARY KEY"
    Database  products  COLUMN_DEF    "price=DECIMAL(12,2) NOT NULL"
    Database  products  INDEX         category

The first line is `Database name source_file type`: this table is named
`products`, its seed/interchange file is `products.txt`, and its storage
is the DSN in the `SQLDSN` Variable (a `dbi:mysql:...` string). Subsequent
lines add per-table options: the key column, SQL column definitions used
when Interchange creates the table, indexes, access controls, and dozens
more cataloged on the [Database directive page](../config/Database.md).

Common `type` values: a `dbi:` DSN (SQL through `Vend::Table::DBI`);
`GDBM`, `DB_FILE`, `SDBM` (DBM files built from the source file);
`MEMORY` (small read-only tables held in RAM); `LDAP`. For DBM types the
text file is authoritative source data; for SQL the file seeds the table
and normal operation reads/writes SQL only.

The special role of **products**: [ProductFiles](../config/ProductFiles.md)
names the table(s) treated as "the catalog" — what
`[field ...]`, flypages, and item pricing consult (strap:
`products variants`). Several directives refine products-table behavior:
[PriceField](../config/PriceField.md),
[DescriptionField](../config/DescriptionField.md),
[HideField/AutoModifier](../config/AutoModifier.md).

## Flat files and imports

Each DBM-backed table watches its source file: when `products.txt` is
newer than the built table, the table is reimported on catalog start or
reconfiguration (suppress with [NoImport](../config/NoImport.md) or
per-table `NO_IMPORT`). The default file format is TAB-delimited with a
header line; per-table options select CSV, pipe, or fixed formats. This
workflow — edit a text file, reconfig, table updates — is why a simple
store can run with no SQL server at all.

SQL tables import their seed file only when Interchange creates the
table. After that, treat the text file as history: live edits happen in
SQL (admin UI, `[query]`, imports below).

Bulk data movement, all usable from pages or jobs:

    [import table=products file=new_products.txt]  ... [/import]
    [export table=products file=products-backup.txt]

plus the [offline](../config/Offline.md) build tool (`bin/offline`) for
big DBM rebuilds and `bin/update` for single-record updates from the
command line. See the [import](../tags/import.md)/[export](../tags/export.md)
tag pages for formats and update-vs-replace semantics.

## Reading data in pages

    [data products description os28005]      any table/column/key
    [field description os28005]               products-table shorthand
    [item-field description]                  inside cart/loop rows
    [loop-field price] / [PREFIX-param ...]   inside loops (see Templating)

`[data ...]` also exposes metadata (`[data products:description meta=1]`)
and increments counters (`increment=1`). Missing keys yield empty strings,
not errors — plan page logic accordingly (`[if data ...]`).

## SQL directly: [query]

Any DBI table takes real SQL, results looping like any list
([Templating](templating.md)):

    [query sql="select sku, price from products where price < 50"
           prefix=cheap]
      [cheap-param sku]: $[cheap-param price]
    [/query]

Placeholders, hash/array return styles, and write statements are on the
[query reference page](../tags/query.md). Catalogs restricted from raw SQL
can be locked down via the Database `WRITE_CONTROL`/ACL options.

## Writing data

- Forms → tables: the admin UI's table editor, or `mv_data_table` form
  processing ([Forms](forms.md)) for controlled user writes (reviews,
  registrations).
- Tags: `[data table=... col=... key=... value=... set=1]` for single
  fields; `[import]`/`[query sql="insert ..."]` for volume.
- Perl: `$Db{table}` objects (`->field`, `->set_field`, `->row_hash`,
  `->set_slice`, `->dbh` for raw DBI) — see
  [Embedded Perl](perl-embedding.md).

Concurrent-write safety differs by backend: SQL backends give you the
database's guarantees (plus `AUTO_SEQUENCE` for generated keys); DBM
writes lock the whole table briefly. High-write tables (orders,
inventory) belong in SQL in production.

## Per-locale and layered tables

`Vend::Table::Shadow` (type `SHADOW`) overlays translated columns per
locale — `description_de_DE` transparently replacing `description` when
the locale is `de_DE` ([Internationalization](internationalization.md)).
strap's `locales/` dbconf files show the setup.

## Choosing backends

| Situation | Choice |
|-----------|--------|
| Small stores, mostly-read tables, no DB server | DBM (GDBM) from flat files |
| Production commerce (orders, inventory, users) | SQL via DBI |
| Static lookup lists (country, state) | DBM or MEMORY |
| Multi-server / replicated | SQL; sessions too ([Sessions](sessions.md)) |

The strap demo runs entirely on any one of MySQL/PostgreSQL/SQLite,
selected at `makecat` time (`ifdef MYSQL ...` in its catalog.cfg), with a
handful of DBM side tables — a sensible template for real stores.

## See also

- [Database directive](../config/Database.md) — every per-table option
- [Search](search.md) · [Forms](forms.md) ·
  [Admin interface](admin-ui.md) (table editor, metadata)
- `eg/` utilities for DBM export and migration
