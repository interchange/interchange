# grep_mm

Filter a list of items down to those the current admin user is permitted to
act on, according to the UI access-control list for a table. It is part of
the administrative UI toolset (loaded only when the admin UI is enabled),
not a storefront tag; the admin uses it to prune keys or columns a user may
not touch.

## Syntax

    [grep_mm function] ITEM ITEM ITEM... [/grep_mm]

Container tag (has an end tag). Its body is the whitespace-separated list of
items to check. The body is interpolated before filtering. Interchange
treats `-` and `_` as equivalent in tag names, so the shipped admin writes
it as `[grep-mm ...]`; that is the same tag.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `function`|         | The access-control facet to check items against (for example `keys` or `fields`). |
| `table`   | `mv_data_table` value | Table whose UI access list is consulted. |

Positional order: `function` (the first parameter).

## Description

The tag looks up the UI access-control record for `table` (via
`UI::Primitive::get_ui_table_acl`). If the table has no access list, the body
is returned unchanged — nothing is restricted. Otherwise the body is split
into items (shell-word style) and each is tested against the access list for
`function`; only the items the current user is allowed are kept. The
surviving items are returned joined by newlines.

This is the list-filtering counterpart to [if_mm](if_mm.md), which tests a
single item; `grep_mm` reduces a whole list in one call.

## Examples

Given a candidate list of row keys, keep only the ones the logged-in admin
user may access in the `orders` table:

    [grep_mm keys table=orders]
      1001 1002 1003 1004
    [/grep_mm]

Filter a set of column names against the current data table's field
permissions:

    [grep_mm fields]
      [loop-code] price cost description
    [/grep_mm]

## Notes

- With no access list configured for the table, the tag is a pass-through;
  restriction only happens where UI access control is in effect.
- Items are separated with shell-word parsing, so quoting rules apply to
  items that contain spaces.

## See also

- [if_mm](if_mm.md) — test a single permission
- [db_hash](db_hash.md) — the access records these checks read
- The [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/grep_mm.coretag`. Implemented by the inline Routine,
which calls `UI::Primitive::ui_acl_grep`.
