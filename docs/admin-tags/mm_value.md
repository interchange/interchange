# mm_value

Return a field from the current administrator's access-control record, or a
per-table ACL setting. Reach for it in admin UI pages to read who is logged in
and what table- or field-level permissions apply.

`[mm_value]` is part of the admin UI tag set in `code/UI_Tag/`, loaded when the
administrative interface is enabled; it is not a storefront tag.

## Syntax

    [mm_value field]
    [mm_value field=yes_fields table=products]

Standalone tag (no end tag). Returns the requested value as a string, or empty
when there is no active admin ACL record.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `field` | none | Which value to return (see Description): `user`, a table-ACL field, or a plain field of the ACL record. |
| `table` | value of `[scratch ui_data_table]` | Table whose per-table ACL is consulted for the table-scoped fields. |
| `user` | current admin user | Look up the ACL for a specific user id instead of the current one. |

Positional order: `field`, `table`. Because the tag declares `addAttr`, the
remaining options are read from the option hash.

## Description

`[mm_value]` reads from the admin access-control record for the current session
(`$Vend::UI_entry`, or the result of `ui_acl_enabled()`). If there is no such
record it returns empty. The value returned depends on `field`:

- **`user`** — Returns the logged-in administrator's user name (from the
  session `ui_username`, `username`, or CGI `user`).
- **A table-ACL field** — For `acl_keys`, `no_fields`, `yes_fields`,
  `no_keys`, `yes_keys`, or `owner_field`, the tag fetches the per-table ACL
  for `table` (via `get_ui_table_acl`) and returns that setting. `acl_keys`
  returns the newline-joined key list; the others return the stored string.
- **Any other field** — Returns that field directly from the top-level ACL
  record.

The table-scoped fields describe row and column permissions: `yes_fields` /
`no_fields` gate columns, `yes_keys` / `no_keys` gate rows, and `owner_field`
names the ownership column used for owner-limited access.

## Examples

Show the current administrator's login name:

    Logged in as [mm_value user].

might render:

    Logged in as admin.

Read the columns the current user is permitted to edit in the `products`
table:

    [mm_value field=yes_fields table=products]

## Notes

`[mm_value]` returns empty outside an authenticated admin session with access
control in effect, so it doubles as a cheap "is an ACL record present" check.

The meaning and format of each ACL field belong to the admin UI access-control
system; this tag only surfaces the stored values.

## See also

- [list_databases](list_databases.md), [list_keys](list_keys.md)
- [if_mm](if_mm.md) — conditional on admin permissions
- Concepts: [admin UI](../guides/admin-ui.md),
  [security](../guides/security.md)

## Source

Defined in `code/UI_Tag/mm_value.coretag` as an inline `UserTag` Routine
(registered `UserTag mm-value`, `addAttr`). Table ACLs come from
`get_ui_table_acl` in `UI::Primitive`.
