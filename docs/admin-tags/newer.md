# newer

Compare two files by modification time and report whether the first is newer
than the second. Reach for it in admin UI pages to detect when a source file
has changed since a derived file was last built — for example whether a
shipping or table source needs reimporting.

`[newer]` is part of the admin UI tag set in `code/UI_Tag/`, loaded when the
administrative interface is enabled; it is not a storefront tag.

## Syntax

    [newer source target]
    [newer source=file1 target=file2]

Standalone tag (no end tag). Returns `1` when `source` is newer than `target`,
`0` when it is not, and empty (undefined) when a file cannot be examined.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `source` | none | The file whose modification time is compared. In the one-argument form (see below), a database name instead. |
| `target` | none | The file compared against. Omit it to use the database-source shortcut. |

Positional order: `source`, `target`.

## Description

`[newer]` `stat`s both files and returns `1` if `source`'s modification time is
strictly greater than `target`'s, otherwise `0`. If `source` cannot be
`stat`ed, it returns undefined (empty).

If `target` is omitted **and** `source` contains no dot, the tag treats
`source` as the name of a configured database and compares that database's DBM
file against its `.asc` source text:

- the DBM file is `source.gdbm` (GDBM) or `source.db` (DB_File), depending on
  which is available — if neither is, the tag returns undefined;
- the text source is the database's configured `file`;
- relative names are resolved under the catalog `ProductDir`.

This lets a page ask "is the built database older than its source file?" —
useful for prompting a reimport.

## Examples

Detect whether a shipping source file is newer than the catalog status file
(as the admin `ship` page does), and prompt to apply changes if so:

    [if type=explicit compare=`
        [newer
            source="[either][scratch ui_shipping_asc][or][var UI_PRODUCT_DIR]/shipping.asc[/either]"
            target=`"$Config->{ConfDir}/status.$Config->{CatalogName}"`
        ]`]
      You need to apply changes for them to take effect.
    [/if]

Database-source shortcut — is the built `products` database older than its
`.asc` source (returns `1` if the source is newer, i.e. an import is due):

    [newer products]

## Notes

The comparison is strict: equal modification times return `0`, not `1`. A
missing `source` returns empty, which in a boolean `[if]` reads as false.

The one-argument database shortcut depends on the server having GDBM or
DB_File support; with neither, it returns undefined even for a valid database
name.

## See also

- [file_info](file_info.md)
- Concepts: [databases](../guides/databases.md),
  [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/newer.coretag` as an inline `UserTag` Routine
(`UserTag newer`).
