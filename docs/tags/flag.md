# flag

Sets a runtime flag on one or more database tables (or on the request), most
often to enable writing or transactions for the rest of the current page.
Reach for it before a page updates a table, or when a block of updates must
commit or roll back together.

## Syntax

    [flag type]
    [flag type=operation table="t1 t2" value=1]

Standalone tag (no end tag). By default it returns nothing.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `type`    | (none)  | The flag operation (see below). |
| `table`   | (none)  | Space-separated list of tables the flag applies to. |
| `value`   | `1`     | Value to set; `0` reverses read/commit-style flags. |
| `status`  | (none)  | Message format returned when `show` is set. |
| `show`    | `0`     | Return a status message instead of nothing. |

Positional order: `type`. Positional and named arguments cannot be mixed —
once any `name=value` attribute is present the bare token is silently
discarded — so write `[flag type=write table=userdb]`, not
`[flag write table=userdb]`. Aliases: `tables`, `flag`, and `name` are all
accepted for `type`/`table` (`tables` → `table`; `flag` and `name` → `type`).

Positional arguments are also never interpolated: a `[tag]` written in a
positional slot arrives as literal text. To build an argument from other
data, use a named attribute with a quoted value — see
[Tag syntax](../guides/templating.md#tag-syntax).
The tag accepts arbitrary additional attributes (`addAttr`).

## Description

The tag maps to `Vend::Interpolate::flag`. When called without a body the first
word of `type` is the operation and the rest (or the `table` attribute) names
the tables. Recognized operations:

- **`write`** — mark the listed tables writable for this request
  (`$Vend::WriteDatabase`). `value=0` (or the `read` operation) clears it.
  Interchange normally opens tables read-only, so a page that writes to a table
  must flag it first.
- **`read`** — the inverse of `write` (sets the write flag to 0).
- **`transactions`** (also `transaction`) — put the tables into transaction
  mode: mark them writable, then close and reopen the table handle in
  transaction mode so a later `commit`/`rollback` applies. Skipped inside the
  Safe compartment.
- **`commit`** / **`rollback`** — commit (or roll back) pending changes on the
  listed tables. Only affects open tables configured with `Transactions`.
- **`checkhtml`** — set the request's `CheckHTML` flag (`$Vend::CheckHTML`).

A table may be given as `table`, `table:column`, or `table:column:key`; only the
table part is used. Unknown operations are logged and ignored.

## Examples

Allow the page to write to the `userdb` table:

    [flag type=write table=userdb]

Enable writing to several tables at once (using the `tables` alias):

    [flag type=write tables="userdb transactions"]

Wrap a set of updates in a database transaction:

    [flag type=transactions table=orderline]
    ... [data ...] updates ...
    [flag type=commit table=orderline]

## Notes

- `write`/`transactions` affect only the current request; the next request
  starts read-only again.
- `commit` and `rollback` do nothing on tables whose driver is not configured
  for transactions.

## See also

- [data](data.md), [import](import.md), [export](export.md) — table writes that
  need the write flag
- Guide: [Databases](../guides/databases.md)

## Source

Defined in `code/SystemTag/flag.coretag`. Implemented by
`Vend::Interpolate::flag` in `lib/Vend/Interpolate.pm`.
