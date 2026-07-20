# import

Import one or more records into an existing database table from the tag body.
Reach for it to seed or update table data inline from a page or job — for
example writing an order record or loading a small lookup table.

## Syntax

    [import table=orders]
    code: [value mv_order_number]
    status: pending
    [/import]

    [import table type=LINE continue=NOTES]...[/import]

Container tag (has an end tag). The body is interpolated as Interchange Tag
Language (ITL) before import. The tag returns `1` on success.

## Attributes

| Attribute   | Default | Description |
|-------------|---------|-------------|
| `table`     | required | Name of the database table to import into. Must already be defined. |
| `type`      | table's configured delimiter | Delimiter type of the body data: `TAB`, `PIPE`, `CSV`, `%%`, or `LINE`. |
| `continue`  | none    | Continuation mode for multi-line/notes fields: `NOTES`, `UNIX`, or `DITTO`. |
| `separator` | form feed (`^L`) | Record separator used with `continue=NOTES`. |
| `file`      | none    | Import from this file instead of the tag body. |

Positional order: `table`, `type`.

Aliases: `base` and `database` for `table`.

Because the tag declares `addAttr`, other named attributes are forwarded to
the import routine as options.

## Description

`[import]` adds records to a [database](../guides/databases.md) table. The
table must already be registered with the
[Database](../config/Database.md) directive — tables cannot be created on the
fly. The record key column is always named `code` and must be present.

The `type` selects the field/record delimiters; when omitted it defaults to
the table's own configured `DELIMITER`. The `LINE` type paired with
`continue=NOTES` is especially convenient: fields are given as
`fieldname: value` lines, so you name each field instead of relying on column
order. In that mode records are separated by the `separator` character (a
form feed by default).

The body may contain multiple records. When `file` is given, data is read
from that file instead (subject to the same file-access restrictions as other
file operations).

## Examples

Import a single order record, naming fields with `LINE`/`NOTES` mode so column
order does not matter:

    [import table=orders type=LINE continue=NOTES]
    code: [value mv_order_number]
    shipping_mode: [shipping-desc]
    status: pending
    [/import]

Import several tab-delimited rows at once (fields in table column order):

    [import table=area_code]
    212	New York
    415	San Francisco
    [/import]

## Notes

Because the body is interpolated first, any ITL in it is expanded before the
records are parsed — useful for pulling values into the import, but be careful
that literal tabs and newlines in interpolated content do not disturb the
delimiter structure.

## See also

- [export](export.md)
- [import_fields](../admin-tags/import_fields.md)
- [data](data.md)
- [Database](../config/Database.md)
- Concepts: [databases](../guides/databases.md)

## Source

Defined in `code/SystemTag/import.coretag`. Implemented by
`Vend::Data::import_text`.
