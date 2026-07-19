# lookup

Treats the input as a database key, looks up a column value in a named table,
and returns it (falling back to the input itself if the lookup finds nothing).

## Syntax

    [filter lookup.TABLE.COLUMN]KEY[/filter]
    [value name=field filter="lookup.TABLE.COLUMN"]

Both dotted arguments are required:

| Argument | Meaning                                  |
|----------|------------------------------------------|
| `TABLE`  | Table to look in                         |
| `COLUMN` | Column whose value to return             |

## Description

The filter calls `tag_data(TABLE, COLUMN, KEY)` — the same access used by the
[data](../tags/data.md) tag — where `KEY` is the input value, and returns the
result. If the lookup returns a false value (no such row, or an empty/zero
field), the filter returns the original input unchanged instead.

Use it to translate a code into a human-readable label inline, without writing
a separate `[data ...]` call. Because the fallback returns the input, a missing
key leaves the value visible rather than blanking it.

## Examples

Using the strap demo `products` table, resolve a SKU to its description:

    [filter lookup.products.description]os28004[/filter]

produces:

    Ergo Roller

If the key is not found, the input is returned as-is:

    [filter lookup.products.description]no_such_sku[/filter]

produces:

    no_such_sku

## See also

- [data](../tags/data.md)
- [Databases guide](../guides/databases.md)

## Source

Defined in `code/Filter/lookup.filter`; the routine calls
`tag_data` (`Vend::Interpolate`).
