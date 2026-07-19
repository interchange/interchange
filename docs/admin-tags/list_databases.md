# list_databases

List the names of the catalog's configured databases (tables), honoring the
administrative access-control rules of the current user. Reach for it to build
table pickers and to hand a table list to `[perl]` in admin UI pages.

`[list_databases]` is part of the admin UI tag set in `code/UI_Tag/`, loaded
when the administrative interface is enabled; it is not a storefront tag.

## Syntax

    [list_databases]
    [list_databases nohide=1 extended=viewname]

Standalone tag (no end tag). In scalar context it returns the table names as
a single space-separated string; called from Perl in list context it returns
the list.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `nohide` | off | When set, returns every configured database with no access-control filtering. |
| `extended` | none | An extended qualifier appended to each table name as `table=extended` before the access-control check, letting per-view ACL rules apply. |

Positional order: `nohide`, `extended`.

## Description

`[list_databases]` reads the keys of `$Vend::Cfg->{Database}` — every database
declared with a `Database` directive in `catalog.cfg` — and returns them
sorted alphabetically.

Unless `nohide` is set, the list is filtered against the current admin user's
table access control:

- A superuser (or a session with no table ACL restrictions) sees every table.
- Otherwise, tables named in the user's `no_tables` list are dropped, and if a
  `yes_tables` list exists, only tables it grants are kept. The `extended`
  qualifier, when given, is checked as `table=extended` against those lists.

The result is the raw table names only; it does not include descriptions or
column information.

## Examples

List every accessible table as a space-separated string:

    [list_databases]

might produce:

    area cat inventory mv_metadata orderline products transactions userdb variants

Feed the list, plus the meta table, to a `[perl]` block that opens each one
(as the stock `dbinfo` page does):

    [perl tables="[list_databases] [var UI_META_TABLE]"]
        return join "\n", sort keys %$Db;
    [/perl]

Bypass access control to enumerate all configured tables:

    [list_databases nohide=1]

## Notes

The access-control filtering relies on the admin UI ACL helpers
(`ui_acl_enabled`, `ui_check_acl`); outside an authenticated admin session
with ACL configured, the tag returns all tables.

## See also

- [list_keys](list_keys.md) — keys within one table
- [mm_value](mm_value.md) — read the current admin ACL record
- Concepts: [databases](../guides/databases.md),
  [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/list_databases.coretag` as an inline `UserTag` Routine
(registered `UserTag list-databases`; the hyphen and underscore spellings are
equivalent when invoked).
