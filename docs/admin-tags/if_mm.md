# if_mm

Conditionally include page content based on whether the current admin user
has permission for a UI task, table, page, or field. It is part of the
administrative UI toolset (loaded only when the admin UI is enabled), not a
storefront tag; it is the primary access-control gate throughout the admin.

## Syntax

    [if_mm function] TRUE-TEXT [/if_mm]
    [if_mm function name] TRUE-TEXT [else] FALSE-TEXT [/if_mm]
    [if_mm !function name] TEXT-WHEN-NOT-PERMITTED [/if_mm]

Container tag (has an end tag). The body is a true/false block using the
standard `[else]` split; output is interpolated. Interchange treats `-` and
`_` as equivalent in tag names, so the shipped admin writes it as
`[if-mm ...]`; that is the same tag.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `function`|         | The permission facet to check (see the groups below). A leading `!` negates the result. |
| `name`    |         | The subject of the check (a table, page/file, field, key, or function name), depending on `function`. |
| `table`   | current data table | Table used for table/field/key checks. |
| `prefix`  |         | Prefix option for page/file glob matching. |

Positional order: `function`, `name` (the first two parameters).
Alias: `key` for `name`.

## Description

The tag evaluates the current user's UI access record (`$Vend::UI_entry`, or
the enabled ACL group) and decides whether the user may do the named thing.
Superusers pass every check. If the user is not logged into the UI, all
checks fail (except the explicit negations).

`function` selects one of several check families:

- `logged_in` — the user is authenticated to the UI.
- `super` — the user is a superuser.
- `tables` / `table` — access to a database table (name in `name`).
- `functions` / `advanced` — access to a named admin function.
- `config` / `reconfig` — configuration privileges.
- `pages` / `files` / `page` / `file` — access to a page or file, matched
  against the user's allowed glob patterns.
- `filematch` / `pagematch` — prefix-based file/page matching.
- `fields` / `columns` / `column` — column-level access on a table.
- `rows` / `keys` / `key` — row/key-level access on a table.
- `owner` / `owner_field` — ownership checks against the table's owner
  column.

An extended qualifier may be appended to `name` with `=` (for example
`=d` for delete on a table permission). When the primary check fails, the
tag also tries any additional groups the user belongs to before concluding.

The tag returns the true block when permitted and the false block (after
`[else]`) otherwise; a leading `!` on `function` swaps the two.

## Examples

Bounce a user who is not logged in (uses [bounce](../tags/bounce.md) and
[set](../tags/set.md)):

    [if_mm !logged_in]
    [set ui_error]Not authorized[/set]
    [bounce page="admin/error"]
    [/if_mm]

Guard a content-editor link behind table access:

    [if_mm tables content]
      <a href="[area content_editor]">Edit content</a>
    [else]
      (no access to the content editor)
    [/if_mm]

Show a delete control only when the user may delete rows in the current
table:

    [if_mm tables "[cgi mv_data_table]=d"]
      <a href="...">Delete</a>
    [/if_mm]

## Notes

- Checks are against the UI access-control records; with no ACL configured
  for a table most checks default to allowed.
- `if_mm` tests one subject at a time. To reduce a whole list of items to
  the permitted ones in a single call, use [grep_mm](grep_mm.md).

## See also

- [grep_mm](grep_mm.md) — filter a list by the same permissions
- [db_hash](db_hash.md) — the access records these checks read
- The [admin UI guide](../guides/admin-ui.md) and
  [security guide](../guides/security.md)

## Source

Defined in `code/UI_Tag/if_mm.coretag`. Implemented by the inline Routine,
which uses `UI::Primitive` access-control helpers.
