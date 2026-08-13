# write_shipping

Write Interchange's in-memory shipping configuration back out to a
`shipping.asc` file. Reach for it from the admin shipping editor after
changing shipping rules in the running server, to persist those rules to
disk.

This tag is part of the administrative UI toolset: it is loaded from
`code/UI_Tag/` when the back-office UI is enabled, and is not a storefront
tag.

## Syntax

    [write_shipping]
    [write_shipping file=path]

Standalone tag (no end tag). It performs a file write as a side effect and
returns nothing useful; its output is reparsed as ITL by default.

The tag name is registered as `write-shipping`; Interchange treats hyphens
and underscores in tag names interchangeably, so `[write_shipping]` and
`[write-shipping]` are the same tag.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `file`    | see below | Destination file. Positional parameter 1. When empty, the tag resolves a default path. |

Positional order: `file`.

The tag declares `addAttr`, so additional attributes are accepted but the
routine acts only on `file`.

## Description

`[write_shipping]` serializes the current `Shipping_line` configuration —
the parsed shipping rules held in the running catalog — into the tab-delimited
`shipping.asc` format and writes it to disk.

When `file` is not supplied, the destination is resolved in this order:

1. the catalog's registered `shipping.asc` special page path, if set;
2. otherwise the `Shipping` directory (or `ProductDir` when unset) joined with
   `shipping.asc`.

Before writing, the tag records the resolved path in
`[scratch ui_shipping_asc]` so the UI knows which file to watch for changes,
and backs up the existing file with
[backup_file](backup_file.md). Each shipping line is written as tab-separated
fields in this order: mode, description, criterion, minimum, maximum, cost,
query, and an options field. When the options field is a hash reference it is
serialized with `uneval` before writing.

The file is opened for truncation, so the previous contents are replaced. On a
write failure the tag dies with an error message naming the file.

## Examples

Persist the current shipping rules to the catalog's default `shipping.asc`:

    [write_shipping]

Write to an explicit path (for example when staging a copy):

    [write_shipping file=products/shipping.asc]

A typical admin flow reads the file, lets the operator edit rules, then writes
it back:

    [read_shipping file=products/shipping.asc]
    [comment] ... operator edits shipping rules ... [/comment]
    [write_shipping file=products/shipping.asc]

## Notes

- The tag writes whatever is currently in `Shipping_line`; it does not read
  the page's form fields. Load the edited rules into the configuration first
  (the admin shipping editor does this) before calling it.
- On failure the routine dies rather than returning an error string.

## See also

- [read_shipping](read_shipping.md) — parse a shipping configuration file
- [backup_file](backup_file.md) — used to back up the file before writing
- [write_relative_file](write_relative_file.md) — general catalog file write
- The [shipping guide](../guides/shipping.md) for the `shipping.asc` format

## Source

Defined in `code/UI_Tag/write_shipping.coretag` as an inline Routine. It reads
`$Vend::Cfg->{Shipping_line}` and calls
[backup_file](backup_file.md) before writing.
