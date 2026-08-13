# db_columns

Return the column names of a database table, in table order or in a
caller-specified order, honoring any admin UI access-control list on the table.
This tag is part of the Interchange admin UI toolset (the tags in
`code/UI_Tag/`, loaded when the admin UI feature is enabled), not a storefront
tag.

## Syntax

    [db_columns name]
    [db_columns name=TABLE columns="col1 col2" joiner=", " passed_order=1]

Standalone tag (no end tag). The return value is a joined string (or a list in
Perl list context); it is not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute      | Default          | Description |
|----------------|------------------|-------------|
| `name`         | `mv_data_table` value | Table whose columns to return. Falls back to the `mv_data_table` form value when empty. |
| `columns`      | all columns      | Whitespace/comma-separated subset of columns to return, filtered against the real column list. |
| `joiner`       | `\n` (newline)   | String used to join the columns when the result is used as a scalar. |
| `passed_order` | `0`              | With `columns`, return them in the order given rather than table order. |

Positional order: `name`, `columns`, `joiner`, `passed_order`.

Aliases: `table` for `name`; `fields` for `columns`.

## Description

`[db_columns]` looks up the table and returns its column names. With no
`columns`, it returns every column in table order. With `columns`, it returns
just those you named that actually exist in the table; the table's key column is
always included.

`passed_order=1` returns the named columns in the order you listed them (still
dropping any that are not real columns) instead of the table's own order.

If the table carries an admin UI field access-control list, the returned
columns are filtered through it, so a user only sees the columns their ACL
permits.

In Perl list context (called as `$Tag->db_columns`) the tag returns the list of
column names; in scalar context (ordinary ITL) it returns them joined by
`joiner`.

## Examples

Loop over every column of the strap `products` table:

    <pre>
    [loop list="[db_columns products]"]
      Column: [loop-code]
    [/loop]
    </pre>

Return a chosen subset as a comma-separated string:

    [db_columns name=products columns="sku description price" joiner=", "]

produces (the key column `sku` is retained):

    sku, description, price

## Notes

A side effect of `passed_order=1` is that invalid column names in `columns` are
removed from the result, instead of being passed through unchanged.

Historic documentation described `db_columns` as a container tag; the current
definition declares no end tag, so it is standalone. Use it inline as shown
above.

## See also

- [loop](../tags/loop.md), [data](../tags/data.md)
- [list_databases](list_databases.md), [quick_table](quick_table.md)
- Concepts: [databases](../guides/databases.md)

## Source

Defined in `code/UI_Tag/db_columns.coretag`. Implemented by the inline Routine,
which uses `Vend::Data::database_exists_ref` and
`UI::Primitive::get_ui_table_acl` / `ui_acl_grep`.
