# OrderCounter

Names the file that holds and increments the running order number. Reach for it
when you want sequential, human-friendly order numbers instead of the default
session-based identifier.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    OrderCounter  filename

A single file path (stored as-is, resolved relative to the catalog root when not
absolute). Default: empty (no counter file; see below).

## Description

When `OrderCounter` names a file, `lib/Vend/Order.pm` uses it to assign each new
order a number. The right-most number in the file's template is found and
incremented on each order, preserving any zero padding. If the directive is
empty, the order number instead becomes a string of the form
`sessionid.unixtime`.

The counter file may be seeded with a template that establishes a prefix and
starting value. A leading comment line and a padded starting number set the
format:

```
#COUNTER-1.0
W-TEST-0000
```

From that seed the next order becomes `W-TEST-0001`, then `W-TEST-0002`, and so
on.

## Examples

Keep the order counter in `etc/order.number` -- the strap demo's setting (in
`catalog.cfg`):

```
OrderCounter etc/order.number
```

## Notes

Interchange provides this counter purely as a convenience for display; no
internal function depends on the order number, so custom numbering schemes are
safe to use. If a [Route](Route.md) is set to `supplant` and defines its own
`counter`, this directive is ignored for that route.

## See also

[Route](Route.md), [CounterDir](CounterDir.md),
[OrderReport](OrderReport.md), the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

## Source

Parsed with no parser (raw string) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{OrderCounter}` in `lib/Vend/Order.pm`.
