# CustomShipping

Supplies an SQL `select` query that returns the rows Interchange uses to
compute shipping costs, replacing the flat-file shipping table with a
database query. Reach for it when your shipping rate data lives in a SQL
table rather than the default shipping file.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    CustomShipping  select ...

A raw string (no parser). Interchange only acts on it when the value
begins with `select` (case-insensitive); any other value is ignored.
Default: empty.

## Description

Interchange normally reads shipping definitions from the shipping table
(the flat `shipping` data). When `CustomShipping` is set to a `select`
query, `lib/Vend/Ship.pm` interpolates the query as Interchange Tag
Language (ITL), runs it, and uses the returned rows in place of the file
data:

```perl
if ($Vend::Cfg->{CustomShipping} =~ /^select\s+/i) {
    my $query = interpolate_html($Vend::Cfg->{CustomShipping});
    ...
}
```

Because the value is interpolated before execution, it may contain ITL
tags and variables, letting you build the query from session or form
data. If the query returns no rows, a shipping error is issued.

## Examples

Draw all shipping rows from a `shipping` SQL table:

```
CustomShipping select * from shipping
```

## Notes

The value must start with `select` or Interchange silently ignores it and
falls back to the normal shipping data. The query is interpolated as ITL,
so escape or avoid characters that would be consumed by the tag parser.

## See also

[DefaultShipping](DefaultShipping.md), [Shipping](Shipping.md),
[Database](Database.md), the [shipping](../guides/shipping.md) guide.

## Source

Stored unparsed in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{CustomShipping}` in `lib/Vend/Ship.pm`.
