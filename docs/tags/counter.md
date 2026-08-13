# counter

Returns the next value of a persistent, named counter, incrementing it as
a side effect. Reach for it to generate sequential order numbers, unique
IDs, or any monotonically increasing value that must survive between
requests.

## Syntax

    [counter file]
    [counter file=name start=N ...]
    [counter sql="table:sequence"]

Standalone tag (no end tag).

## Attributes

| Attribute     | Default         | Description |
|---------------|-----------------|-------------|
| `file`        | `etc/counter`   | Counter file, relative to `CounterDir` (or the catalog root) unless absolute. |
| `start`       | (module default)| Initial value when the counter is first created. |
| `value`       | `0`             | Return the current value without changing it (file counters only). |
| `decrement`   | `0`             | Decrement instead of increment. |
| `date`        | (none)          | Make a date-based counter; `gmt` uses GMT. |
| `inc_routine` | (none)          | Custom increment routine (Perl sub, catalog `Sub`, or `GlobalSub`). |
| `dec_routine` | (none)          | Custom decrement routine. |
| `sql`         | (none)          | `table:sequence` — use an SQL sequence instead of a file. |
| `bypass`      | `0`             | For `sql`, open a fresh DBI connection instead of reusing the table's. |
| `dsn`         | `$DBI_DSN`      | DSN for a bypassed SQL connection. |
| `user`        | (none)          | Username for a bypassed SQL connection. |
| `pass`        | (none)          | Password for a bypassed SQL connection. |
| `attr`        | (none)          | Extra attributes for the `DBI->connect` call. |

Positional order: `file`. Alias: `name` for `file`. `[counter]` accepts
arbitrary additional attributes (`addAttr`).

## Description

The tag maps to `Vend::Interpolate::tag_counter`. With no `sql` option it
uses a file-based counter (`Vend::CounterFile`): the file lives under
`CounterDir` if that directive is set, otherwise under the catalog root
(`VendRoot`), unless you give an absolute path. Access is subject to
Interchange's file-permission checks, so the path must be an allowed file.

By default each call returns the next value and increments the stored
number. `value=1` returns the current value without touching it;
`decrement=1` returns the previous value instead. `date=1` (or
`date=gmt`) produces a counter keyed to the current date. A custom
`inc_routine`/`dec_routine` — named as a catalog `Sub`, a `GlobalSub`, or
given inline as a Perl sub — replaces the default +1/-1 step; each routine
receives the current value and returns the new one.

With `sql="table:sequence"` the counter comes from a database sequence
instead of a file: for PostgreSQL/Oracle-style sequences the tag issues the
appropriate `nextval` query, reusing the table's existing handle unless
`bypass=1` forces a new connection. If the SQL counter fails, the error is
logged once and the tag falls back to the file counter.

## Examples

A basic file counter starting at 10, stored in `counter.basic` in the
catalog root:

    [counter file=counter.basic start=10]

Read the current value without incrementing:

    [counter file=counter.basic value=1]

A date-based counter:

    [counter file=counter.loc date=1]

Step by two using an inline routine:

    [counter file=counter.p2 start=20 inc-routine=`sub { shift(@_) + 2 }`]

Use a PostgreSQL sequence named `counter1`:

    [counter sql="table1:counter1"]

## Notes

The SQL field-updating behavior is database-dependent; PostgreSQL,
MySQL-style `AUTO_INCREMENT`, and Oracle sequences are handled, but for
other databases consult the tag source. Date-based counters cannot be
decremented.

`[fcounter]` is an alias of `[counter]`.

## See also

[fcounter](fcounter.md), [value](value.md),
[CounterDir](../config/CounterDir.md).

## Source

Defined in `code/SystemTag/counter.coretag`. Implemented by
`Vend::Interpolate::tag_counter` in `lib/Vend/Interpolate.pm`.
