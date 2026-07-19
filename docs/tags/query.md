# query

Run an SQL (or Interchange search-engine) query against a catalog table and
iterate the rows over the tag body. It is the workhorse for ad-hoc data access
that goes beyond a single [field](field.md) or [data](data.md) lookup —
multi-row reports, joins, aggregates, and cross-table selects.

## Syntax

    [query list=1 sql="SELECT ..."]
    [sql-param COLUMN] ... row template ...
    [/query]

    [query sql="UPDATE ..."]

Container tag (has an end tag). With `list=1` the body is a looping region,
interpolated once per row; without it the tag runs the statement and returns its
raw result (a row count for writes).

## Attributes

| Attribute  | Default        | Description |
|------------|----------------|-------------|
| `sql`      | none           | The SQL statement (positional). May also be given as the tag body when no template is needed. |
| `table`    | first products table | Table whose database connection runs the query. |
| `list`     | off            | Iterate the result rows over the body (the display form). |
| `type`     | none           | Shorthand that turns on a named option: `type=list`, `type=html`, `type=hashref`, `type=arrayref`. |
| `html`     | off            | Return the result as an HTML `<table>` instead of iterating. |
| `prefix`   | `sql`          | Sub-tag prefix used inside the body (`[sql-code]`, `[sql-param ...]`). |
| `hashref`  | none           | Name under which to store the rows (as a hash) in `$Tmp` for embedded Perl. |
| `arrayref` | none           | Name under which to store the rows (as an array) in `$Tmp` for embedded Perl. |
| `values`   | none           | Space/quote-separated names whose [values](value.md)-space entries fill `?`/`%s` placeholders. |
| `wantarray`| none           | Return `($ref, $name_hash, $names)` to an embedded-Perl caller. |
| `failure`  | none           | Value returned if the named table or its connection is missing. |
| `ml`, `md`, `more` | none   | Pagination controls, passed through to the list machinery. |

Positional order: `sql`.

Alias: `base` for `table`.

The tag declares `addAttr`, so any additional list/region options are accepted
and forwarded.

## Description

`[query]` resolves the table (defaulting to the catalog's first products table),
substitutes any quoting sub-tags, and executes the statement through that
table's database driver. For a table backed by a real SQL engine the statement
is run via DBI; for a GDBM/Berkeley (non-SQL) table Interchange's own SQL-subset
search engine handles simple `SELECT`s.

What the tag returns depends on the options:

- **`list=1`** — the rows are iterated over the body as a region with the `sql`
  prefix. This is the normal display form.
- **`type=html`** (or `html=1`) — the rows are rendered as an HTML table.
- **`arrayref=NAME` / `hashref=NAME`** — the rows are stored in
  `$Tmp->{NAME}` (reachable as `$Tmp->{NAME}` in embedded Perl) and nothing is
  displayed.
- **no option** — a data-modifying statement (`INSERT`/`UPDATE`/`DELETE`)
  returns the affected row count; a bare `SELECT` returns the raw result
  reference, which is normally only useful to embedded Perl.

### Prefix sub-tags

Inside a `list=1` body, the returned columns are reached through sub-tags whose
prefix is `sql` (change it with `prefix=`):

- `[sql-code]` — the row's key (its first returned column)
- `[sql-param NAME]` / `[sql-pos N]` — a returned column, by name or position
- `[sql-increment]` — the 1-based row counter
- `[if-sql-field NAME] ... [/if-sql-field]` — per-row conditional
- `[on-match] ... [/on-match]` / `[no-match] ... [/no-match]` — run when the
  query did or did not return rows

See [templating](../guides/templating.md) for the complete looping-tag model
these share with [loop](loop.md) and [item-list](item-list.md).

### Quoting user input

Never paste form input straight into SQL. The `[sql-quote]...[/sql-quote]`
sub-tag returns its body correctly quoted for the table's database, and
`[sql-quote-identifier]...[/sql-quote-identifier]` quotes an identifier (table
or column name). Both use the `prefix` value, so with `prefix=cat` they become
`[cat-quote]` and so on.

## Examples

Iterate products and print two columns per row:

    [query list=1 sql="select sku, description from products order by sku"]
    [sql-param sku]: [sql-param description]<br>
    [/query]

Safely search on a submitted keyword, quoting the value:

    [query list=1 sql="
        select sku, description from products
        where description like [sql-quote]%[value keywords]%[/sql-quote]
    "]
    [sql-param sku] — [sql-param description]<br>
    [no-match]No products matched.[/no-match]
    [/query]

Render an ad-hoc result straight to an HTML table:

    [query sql="select sku, description, price from products" type=html]

Load rows into `$Tmp` and work with them in embedded Perl:

    [query arrayref=rows sql="select sku from products"][/query]
    [perl]
        return "There are " . scalar(@{$Tmp->{rows}}) . " products.";
    [/perl]

Update a row — returns the number of rows changed:

    [query sql="update products set price = '5.00' where sku = 'os28004'"]

## Notes

The default table is the catalog's first `ProductFiles` entry (usually
`products`); name another with `table=`. To search the non-SQL DBM tables with
this tag, use only the simple `SELECT` forms the built-in engine supports, or
add `st=db` as documented for [loop](loop.md).

Wrap queries that can die (bad SQL, a missing table) in a [try](try.md) block if
you need the page to survive the failure; otherwise a failed query logs an error
and returns undef (or `failure`).

## See also

- [loop](loop.md), [region](region.md), [item-list](item-list.md),
  [field](field.md), [data](data.md), [record](record.md), [try](try.md)
- Concepts: [databases](../guides/databases.md),
  [templating](../guides/templating.md), [search](../guides/search.md)

## Source

Defined in `code/SystemTag/query.coretag`. Implemented by
`Vend::Interpolate::query`, which dispatches to the table driver's `query`
method (`Vend::Table::DBI::query` for SQL tables).
