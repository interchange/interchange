# safe_data

Allows data returned from a database to be reparsed for Interchange Tag Language
(ITL) tags. By default Interchange escapes `[` in database output so stored tags
are shown literally; setting `safe_data` removes that protection. Reach for it
only when you deliberately store ITL in a column and understand the security
implications.

**Default:** off — `[` in database output is escaped to `&#91;` so stored tags
are not executed.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma safe_data

Page-wide, anywhere in an Interchange page:

    [pragma safe_data]
    [pragma safe_data 0]

Block-wide, around an ITL block:

    [tag pragma safe_data]1[/tag]

This is a boolean pragma.

## Description

The `ed()` routine escapes `[` characters in values pulled from the database, so
that a product description containing `[page ...]` displays as text rather than
being executed as a tag. When `safe_data` is set (or the internal `$Safe_data`
flag is active), `ed()` returns the value unchanged, so any ITL tags in the data
are interpolated.

This is a security-sensitive switch: enabling it means anyone who can write to
the database can inject tags that Interchange will execute.

## Examples

Enable it for a single page that needs `[page]` links inside product
descriptions, wrapping the risky area in [restrict](../tags/restrict.md) so only
safe tags are honored:

    [pragma safe_data]
    [restrict enable="page area"]
    [item-list]
      [item-field description]
    [/item-list]
    [/restrict]

## Notes

Many tags accept a `safe_data` attribute, which enables reparsing for just that
tag's data without turning on the pragma page-wide. Prefer the attribute, or a
narrowly scoped `[tag pragma safe_data]` / `[pragma safe_data]`, over a
catalog-wide `Pragma safe_data`.

Always surround reparsed data with [restrict](../tags/restrict.md) to allow only
a known-safe set of tags (such as `[page]` or `[area]`). Expect security
compromises if you allow powerful tags such as `[calc]` or `[perl]`.

Watch out for parse order with `[tag pragma]` or [restrict](../tags/restrict.md)
when used with lists that retrieve data from the database (`[PREFIX-*]`,
[loop](../tags/loop.md), the flypage). Loops parse before regular tags like
`[tag]` and `[restrict]`, so the whole loop must be inside the critical section
to be affected.

Also consider whether the same data will ever be used outside a tag-parsing
context (for example, in a plain-text email receipt), where a literal
`[page ...]` would leak into the output.

## See also

- [restrict](../tags/restrict.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `ed()` in
`lib/Vend/Interpolate.pm`.
