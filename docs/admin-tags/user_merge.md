# user_merge

Merge one or more user accounts into a target user, moving their transactions
and order lines and combining their saved carts, then deleting the merged
accounts. Reach for it from the admin customer screens to consolidate
duplicate accounts, keyed either by username or by order number.

This tag is part of the administrative UI toolset: it is loaded from
`code/UI_Tag/` when the back-office UI is enabled, and is not a storefront
tag. It requires administrator privileges (see Description).

## Syntax

    [user_merge from=USERS to=TARGET table=userdb]
    [user_merge from=FROM to=TO from_order=1]

Standalone tag (no end tag). It performs the merge as a side effect. By
default it returns `1` on success; its output is reparsed as Interchange Tag
Language (ITL) by default.

The tag name is registered as `user-merge`; Interchange treats hyphens and
underscores in tag names interchangeably, so `[user_merge]` and `[user-merge]`
are the same tag.

## Attributes

| Attribute      | Default | Description |
|----------------|---------|-------------|
| `from`         | CGI `item_id` | Account(s) to merge away. May be a single value, a null-separated list, or an array reference. When `from_order` is set, these are order numbers. Positional parameter 1. |
| `to`           | CGI `item_radio` | Target account (or, with `from_order`, the target order number) that everything is merged into. Positional parameter 2. |
| `table`        | CGI `mv_data_table` | Source context. `userdb` implies `from_user`; `transactions` implies `from_order`. |
| `from_user`    | none    | Treat `from`/`to` as usernames. |
| `from_order`   | none    | Treat `from`/`to` as order numbers; the usernames are resolved from those orders. |
| `user_field`   | `username` | User-key column in the merge tables. |
| `order_field`  | `order_number` | Order-key column used when resolving usernames from orders. |
| `user_table`   | `UI_USER_MERGE_USER_TABLE` or `userdb` | The user database table. |
| `merge_tables` | `UI_USER_MERGE_TABLES` or `transactions orderline` | Tables whose user key is rewritten from the merged users to the target. |
| `logfile`      | `logs/merged_users.log` | Where the merge audit trail is written. |
| `no_delete`    | none    | Rewrite the merged users' records but do not delete the old user rows. |
| `hide`         | none    | Return an empty string instead of `1` on success. |
| `debug`        | none    | Also write the operation record to the debug log. |

Positional order: `from`, `to`. Named and positional parameters cannot be
mixed: if any `name=value` attribute is present, the tag takes the named path
and bare positional tokens are silently discarded. Since `table`, `from_user`,
and `from_order` are named-only, `from=` and `to=` should be named too.

The tag declares `addAttr`. `merge_tables` may list `table=keyfield` pairs
(for example `orderline=username`) to override the key column per table.

## Description

The tag first checks authorization: the session must be an admin session
(`$Vend::admin`), and unless it is the superuser it must additionally pass the
`if_mm('advanced', 'merge_users')` permission check. Without that it logs an
error and returns undef.

It then determines a direction. If `from_user`/`from_order` are set explicitly
they are honored; otherwise the source `table` decides (`userdb` means merge by
user, `transactions` means merge by order). With `from_order`, each `from`
order number is looked up to find its owning username, and those usernames
become the accounts to merge.

For each source user (skipping the target itself and any that do not exist),
the tag:

- runs the `user_merge` [SpecialSub](../config/SpecialSub.md), if one is
  configured, passing the source and target records; a true return from the
  sub skips the rest of the processing for that user;
- rewrites the user key in every `merge_tables` table from the source user to
  the target user with a prepared SQL `UPDATE`;
- merges the source user's saved carts into the target's, keeping the target's
  cart when a name collides and logging the skipped one;
- deletes the source user record (unless `no_delete` is set).

Every step is appended to `logfile` along with a timestamp and a dump of each
deleted user record. On success the tag returns `1`, or an empty string when
`hide` is set.

The `UI_USER_MERGE_USER_TABLE` and `UI_USER_MERGE_TABLES`
[variables](../variables/README.md) let a catalog change the default user
table and the set of tables rewritten, without passing attributes on every
call.

## Examples

Merge two duplicate usernames into a surviving account:

    [user_merge from="olduser1
    olduser2" to=gooduser table=userdb]

Merge by order number, letting Interchange resolve the usernames (as the admin
order screens do, taking `from`/`to` from the checkbox and radio fields):

    [user_merge from_order=1]

Rewrite the linked records but keep the old user rows for review:

    [user_merge from=olduser to=gooduser table=userdb no_delete=1]

## Notes

- Table key rewrites are done with live SQL `UPDATE` statements and account
  deletion is permanent (absent `no_delete`); the operation is not
  transactional across tables. Run it against a known-good backup.
- The merge is admin-only and additionally gated by the `merge_users`
  advanced permission for non-superusers.

## See also

- [if_mm](if_mm.md) — the admin permission check used here
- [SpecialSub](../config/SpecialSub.md) — the `user_merge` hook
- The [user database guide](../guides/user-database.md)

## Source

Defined in `code/UI_Tag/user_merge.tag` as an inline Routine. It uses
`dbref` table handles, prepared SQL `UPDATE` statements, and the `user_merge`
`SpecialSub` hook.
