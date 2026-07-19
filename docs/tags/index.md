# index

Rebuild the sorted search index (`.idx`) for a database table. Reach for it
after loading or changing table data when you use Interchange's built-in
text search, so searches read from a current, pre-sorted index.

## Syntax

    [index table]
    [index table=products fields="category price"]
    [index table=products export_only=1]

Standalone tag (no end tag). It returns nothing by default (or `1` with
`show_status`).

## Attributes

| Attribute     | Default | Description |
|---------------|---------|-------------|
| `table`       | required | Name of the database table to index. |
| `fields`      | none    | Whitespace/comma/null-separated list of fields to build the index on (the sort/return columns). |
| `extension`   | `idx`   | File extension appended to the table's text source to name the index file. |
| `basefile`    | table's `db_text` source | Base text file to index against and re-export to. |
| `type`        | table's configured type | Database type used when re-exporting the source. |
| `export_only` | `0`     | Only (re)export the table's text source; skip building the index. |
| `spec`        | none    | A full raw search spec to drive the index, instead of `fields`. |
| `show_status` | `0`     | Return `1` on success instead of an empty string. |

Positional order: `table`.

Aliases: `base` and `database` for `table`; `fn`, `col`, and `columns` are
accepted as synonyms of `fields`.

Because the tag declares `addAttr`, other named attributes are forwarded to
the routine as options.

## Description

`[index]` builds a secondary index file (`TABLE.txt.idx` by default) that
Interchange's text-search engine can scan instead of the full table. It first
ensures the table's ASCII source is current — re-exporting it if the live
database file is newer — then, unless `export_only` is set, performs an
internal search that writes the requested fields, sorted, to the index file.

If the existing index is already newer than the source, the tag does nothing.
You must supply the fields to index (`fields`, or the equivalent `fn`/`col`/
`columns`), or a complete `spec`; with neither, the tag logs an error and
returns without indexing.

The table key column is always included implicitly and is excluded from the
supplied field list when the sort spec is built.

## Examples

Rebuild the index for the `products` table on the `category` and `price`
fields:

    [index table=products fields="category price"]

Only refresh the exported text source, without reindexing:

    [index table=products export_only=1]

Index and report success:

    [index table=area fields=state show_status=1]

produces:

    1

## Notes

Indexing runs a full internal search over the table, so it is a maintenance
operation best done from a [job](../guides/jobs.md) or admin action rather
than on every page view.

## See also

- [export](export.md)
- [import](import.md)
- [search](search.md)
- [StaticIndex](../config/StaticIndex.md)
- Concepts: [search](../guides/search.md),
  [databases](../guides/databases.md)

## Source

Defined in `code/SystemTag/index.coretag`. Implemented by
`Vend::Data::index_database`.
