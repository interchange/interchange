# list_keys

List the primary-key values of a database table, honoring the administrative
user's row-level access control. Reach for it to build a record picker for an
editable table in the admin UI.

`[list_keys]` is part of the admin UI tag set in `code/UI_Tag/`, loaded when
the administrative interface is enabled; it is not a storefront tag.

## Syntax

    [list_keys table]
    [list_keys table=products]

Standalone tag (no end tag). In scalar context it returns the keys joined with
newlines; called from Perl in list context it returns the list.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `table` | value of `[value mv_data_table]` | The table whose key column is listed. Falls back to the `mv_data_table` form value when omitted. |

Positional order: `table`.

Because the tag declares `addAttr`, additional attributes are accepted but the
routine reads only the table.

## Description

`[list_keys]` returns the values of the table's key column. It resolves the
list in this order:

1. If the admin user's table ACL defines an explicit `yes_keys` list for the
   table, those keys are used directly.
2. Otherwise the tag queries `select KEY from table order by KEY`, limited by
   the `UI_ACCESS_KEY_LIMIT` variable (default 500 rows). Keys are sorted
   numerically when the key column is numeric, alphabetically otherwise.

If the table is flagged `LARGE` in its configuration, the tag refuses to
enumerate it and returns the message `--not listed, too large--`. A
nonexistent table returns the empty string.

After the list is built, any table ACL (`ui_acl_grep` on the `keys` domain) is
applied to remove keys the user may not see.

## Examples

List the SKUs in the strap `products` table:

    [list_keys products]

produces (newline-separated, up to the access limit):

    00-0011
    os28004
    os28005
    os28057a
    os28057b

Build a select box of transaction ids:

    <select name="ui_key">
    [loop list="[list_keys transactions]"]
      <option>[loop-code]</option>
    [/loop]
    </select>

## Notes

The 500-key default limit exists to keep large tables from producing huge
pickers; raise or lower it with the `UI_ACCESS_KEY_LIMIT` catalog variable.
Tables marked `LARGE` are never enumerated regardless of the limit.

## See also

- [list_databases](list_databases.md) — list table names
- [mm_value](mm_value.md) — read the current admin ACL record
- Concepts: [databases](../guides/databases.md),
  [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/list_keys.coretag` as an inline `UserTag` Routine
(registered `UserTag list-keys`; hyphen and underscore spellings are
equivalent when invoked). ACL helpers are in `UI::Primitive`.
