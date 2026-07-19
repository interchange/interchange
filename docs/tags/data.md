# data

Reads (or sets) a single field of any database table by key, or a value in
the user's session. Reach for it whenever you need a value from a table
other than `products`, or want to write to a table from a page.

## Syntax

    [data table field key]
    [data table=t column=c key=k value=v ...]
    [data session field]

Standalone tag (no end tag).

## Attributes

| Attribute   | Default | Description |
|-------------|---------|-------------|
| `table`     | (none)  | Table to read from, or the literal `session`. |
| `field`     | (none)  | Column (field) to read or write. |
| `key`       | (none)  | Row key (primary key) to look up. |
| `value`     | (unset) | Present ⇒ set the field to this value instead of reading. |
| `increment` | `0`     | Add `value` (default 1) to a numeric field. |
| `append`    | `0`     | Append `value` to the field instead of overwriting. |
| `filter`    | (none)  | Filter applied to the value on read or before write. |
| `foreign`   | (none)  | Look up the row by this column instead of the primary key. |
| `hash`      | `0`     | Return the whole row as a hash reference. |
| `alter`     | (none)  | `change`, `add`, or `delete` a column (schema change). |
| `safe_data` | `0`     | Mark the returned data as safe. |

Positional order: `table`, `field`, `key`.

Aliases: `column`, `col`, `name` for `field`; `code`, `row` for `key`;
`base`, `database` for `table`. `increment` may be supplied bare. The tag
accepts arbitrary additional attributes (`addAttr`).

## Description

The tag maps to `Vend::Interpolate::tag_data`. Its behavior depends on the
attributes:

**Read (the default).** With just `table`, `field`, and `key` it returns
that field's value for that row. If the row or column does not exist it
returns an empty string (and logs a "Bad data selector" error for an
unknown table). A `filter` is applied to the value before it is returned.

**The session pseudo-table.** When `table` is the literal `session`, the
tag reads (or, with `value`, writes) a key in the current user's session
hash instead of a database — useful for values like `username`, `host`, or
`logged_in`. Do not name a real database `session`, or it will be masked.

**Write.** Supplying `value` sets the field (subject to `append`,
`increment`, `filter`, `serial`). The target table must be writable on the
current page; DBM tables in particular need
`[tag flag write]tablename[/tag]` before the first access. `increment`
adds `value` (defaulting to 1) to a numeric field; `append` concatenates.

**Whole row.** `hash=1` returns the entire row as a hash reference (keyed
by column name), most useful from embedded Perl.

**Foreign key.** `foreign=column` looks the row up by a non-primary-key
column; the first match is returned.

**Schema.** `alter=change|add|delete` with `value` alters the table's
columns — a maintenance operation, not page display.

## Examples

Read the price of SKU `os28004` from the strap `products` table:

    [data products price os28004]

Read a value from the user's session:

    [data session username]

Increment an inventory quantity (writes the `inventory` table):

    [data inventory qty 99-102 1 increment]

which is equivalent to the named form:

    [data base=inventory name=qty code=99-102 value=1 increment=yes]

Look up a row by a non-key column:

    [data table=products column=price foreign=description key="Mostly Sunny"]

Fetch a whole row as a hash in embedded Perl:

    [perl tables=products]
      my $row = $Tag->data({ table => 'products', key => 'os28004', hash => 1 });
      "SKU os28004 costs $row->{price}";
    [/perl]

## Notes

For the `products` table specifically, [field](field.md) is a shorter
read-only equivalent. `[data]` is the general form that works on any table
and can also write.

Writing requires the table to be flagged writable first; a silent failure
to write usually means the flag was missing or the page lacks write access.

## See also

[field](field.md), [tag](tag.md), [value](value.md), the
[databases](../guides/databases.md) and
[sessions](../guides/sessions.md) guides.

## Source

Defined in `code/SystemTag/data.coretag`. Implemented by
`Vend::Interpolate::tag_data` in `lib/Vend/Interpolate.pm`.
