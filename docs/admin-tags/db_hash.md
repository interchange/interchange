# db_hash

Read or write one value inside a serialized Perl hash that is stored in a
single database field, addressing nested members by a colon-separated key
path. It is part of the administrative UI toolset (loaded only when the
admin UI is enabled), not a storefront tag; the admin uses it to read the
per-user access-control records kept in the `access` table.

## Syntax

    [db_hash table column key]
    [db_hash table=t column="col:member:member" key=k value=... keys=1]

Standalone tag. Interchange treats `-` and `_` as equivalent in tag names,
so the admin pages that ship with Interchange write it as `[db-hash ...]`;
that is the same tag.

## Attributes

| Attribute    | Default | Description |
|--------------|---------|-------------|
| `table`      |         | Database table holding the serialized hash. |
| `column`     |         | Field name, optionally followed by a colon path into the hash. |
| `key`        |         | Row key (primary key value) of the record to read. |
| `value`      |         | If given, stores this value at the addressed member and writes the hash back. |
| `keys`       |         | If true, return the sorted keys of the addressed sub-hash instead of a value. |
| `joiner`     | space   | Separator used when `keys` returns a list. |
| `show_error` |         | If true, return a diagnostic `BAD HASH: ...` string when the path cannot be walked. |

Positional order: `table`, `column`, `key` (the first three parameters).
All other parameters are named.

## Description

The field named by `column` is expected to contain an `uneval`-style Perl
data structure (a hash reference). The tag reads that field for the given
`key`, evaluates it in the interpolation Safe compartment, and then walks
into the structure.

The member path is appended to the column name with colons:

    column:member1:member2:finalkey

Everything up to the first run of colons is the real field name; the rest is
split on colons into the path. The last path element is the member that is
read or written; the earlier elements are sub-hashes that must exist. When
the column has no colon path and no `value` is supplied, the raw field text
is returned unchanged.

Behavior by option:

- Plain read (no `value`, no `keys`): returns the scalar at the final path
  element.
- `keys=1`: returns the sorted keys of the sub-hash at the final path
  element, joined by `joiner`.
- `value=...`: sets the final path element to that value, re-serializes the
  whole structure with `uneval`, and writes it back to the field with
  [data](../tags/data.md)'s underlying store. Returns the value just set.

If an intermediate path element is not a reference, the tag returns empty,
or the string `BAD HASH: ...` (showing the path walked so far) when
`show_error` is set.

## Examples

Read the `yes_keys` permission list for the current admin user out of the
`access` table's `table_control` field (the structure is keyed first by
table name, then by permission type):

    [db_hash
        table=access
        column="table_control::[value mv_data_table]::yes_keys"
        key="[data session username]"]

Store the raw contents of the whole field into a scratch variable using
[tmp](../tags/tmp.md):

    [tmp owner][db_hash
        table=access
        column="table_control::[value mv_data_table]::owner_field"
        key="[data session username]"][/tmp]

List the member names one level down:

    [db_hash table=access column="table_control::products" key=fred keys=1]

## Notes

- The stored value is evaluated as Perl in the interpolation Safe
  compartment. Only use this tag against fields your application controls.
- A double colon in the column (as in the shipped examples) is just the
  field name followed by a colon path; the first colon run is the boundary.

## See also

- [data](../tags/data.md) — general database field access
- [if_mm](if_mm.md) — the admin permission checks that consume these records
- The [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/db_hash.coretag` (registered as `db-hash`).
Implemented by the inline Routine in that file.
