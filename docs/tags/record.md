# record

Write several columns of one database record in a single operation. Give it a
table, a key, and a hash of column/value pairs, and it upserts them all at
once — the multi-column counterpart of a single-field
[data](data.md) write.

## Syntax

    [record table=products key=os28004 col.price=5.00 col.description="On sale"]

Standalone tag (no end tag). Returns the status of the underlying write
(nothing useful for display in normal use); its purpose is the side effect.

## Attributes

| Attribute    | Default | Description |
|--------------|---------|-------------|
| `table`      | none    | Database table to write to. |
| `key`        | none    | Key (primary-key value) of the record to write. |
| `col`        | none    | Hash of *column* => *value* pairs to set. Must be a hash reference. |
| `filter`     | none    | Hash of *column* => *filter* pairs; each value is passed through the named filter before writing. |
| `show_error` | none    | If set, return the error text when the write dies. |

Positional order: none (`PosNumber 0`).

Aliases: `column` and `field` for `col`; `code` for `key`.

Build the `col` hash with the dotted-attribute form: `col.`*column*`=`*value*
sets one entry (`col.price=5.00`), and repeated `col.*` attributes accumulate
into the hash. `filter.`*column*`=`*name* works the same way.

## Description

`[record]` collects the `col` hash, validates each key against the table's real
columns (any unknown column is dropped and logged), applies any matching
`filter`, and calls the table's `set_slice` method for `key`. `set_slice` is an
*upsert*: it updates the row if `key` exists and inserts it otherwise. All the
listed columns are written in one call, which for SQL backends is a single
statement.

If `col` is not a hash reference, or `key`/the named table is missing, the tag
does nothing and returns undef. When the write raises an error, the error is
returned only if `show_error` is set; otherwise it is swallowed.

Because the value of `col` must be a real hash, `[record]` is most natural when
built from embedded Perl or driven by the dotted-attribute syntax; a single
field is usually easier to set with [data](data.md) or
[value](value.md).

## Examples

Update two columns of a product in one call:

    [record table=products key=os28004 col.price=5.00 col.description="Clearance"]

Filter a value before storing it — here strip everything but digits and the
decimal point from a submitted price:

    [record table=products key=os28004
            col.price="[value newprice]"
            filter.price=digits_dot]

## Notes

> The historic reference and the extraction notes describe `[record]` as
> *returning* an entire record. The current code does the opposite: it *writes*
> a slice of columns via `set_slice`. This page documents the code. To read a
> whole record, iterate it with [loop](loop.md)/[query](query.md) or read
> individual fields with [field](field.md) and [data](data.md).

Unknown columns are silently skipped (with a log entry), so a typo in a
`col.*` name will not raise an error — check your column names against the
table definition.

## See also

- [data](data.md), [field](field.md), [value](value.md), [import](import.md)
- Filters: [digits_dot](../filters/digits_dot.md)
- Concepts: [databases](../guides/databases.md)

## Source

Defined in `code/SystemTag/record.coretag` as an inline Routine that calls the
table's `set_slice` method (see `Vend::Table::Common::set_slice` and the
DBI/GDBM variants).
