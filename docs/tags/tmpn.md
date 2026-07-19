# tmpn

Set a temporary scratch variable to the raw (un-interpolated) body, marking it
for automatic deletion at the end of the page. The non-interpolating companion
of [tmp](tmp.md).

## Syntax

    [tmpn NAME]VALUE[/tmpn]

Container tag. The body (`VALUE`) is stored verbatim — ITL inside it is **not**
processed. The tag returns the empty string.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    |         | Name of the scratch variable to set. |

Positional order: `name` (`PosNumber 1`). The body is the value.

## Description

`[tmpn]` behaves exactly like [tmp](tmp.md) — it assigns to a scratch variable
(readable with [scratch](scratch.md) or as `$Scratch->{NAME}`) whose name is
queued for deletion once the page is served, and which is never written to the
session — except that the body is stored **without** interpolation. Use it when
the value must contain literal ITL, or when you deliberately want to defer
interpolation of the stored text to a later point.

For the interpolating version, use [tmp](tmp.md), or pass `interpolate=1`.

## Examples

Store a literal ITL snippet to interpolate later:

    [tmpn greeting]Hello, [value name=fname]![/tmpn]

`[scratch greeting]` now yields the raw string
`Hello, [value name=fname]!`, which you can interpolate on demand.

Set a fixed class name used once on the current page:

    [tmpn display_class]noleft[/tmpn]

## Notes

The value lives in the regular scratch space (`$Scratch`), not in the `$Tmp`
space used by [tn](tn.md)/[tv](tv.md). As with [tmp](tmp.md), a name already in
scratch is overwritten for the rest of the page.

## See also

[tmp](tmp.md), [set](set.md), [scratch](scratch.md), [tn](tn.md), [tv](tv.md),
the [templating](../guides/templating.md) guide.

## Source

Defined in `code/SystemTag/tmpn.coretag`. Implemented by
`Vend::Interpolate::set_tmp` in `lib/Vend/Interpolate.pm`; the temporary names
are cleared in `Vend::Session`.
