# tmp

Set a temporary scratch variable to the interpolated body, marking it for
automatic deletion at the end of the page. Reach for it for short-lived values
you do not want persisted in the session.

## Syntax

    [tmp NAME]VALUE[/tmp]

Container tag. The body (`VALUE`) is interpolated before assignment. The tag
itself returns the empty string.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    |         | Name of the scratch variable to set. |

Positional order: `name` (`PosNumber 1`). The tag takes no other attributes;
the body is the value.

## Description

`[tmp]` assigns the interpolated body to a scratch variable — the same store
read by [scratch](scratch.md) and accessible in embedded Perl as
`$Scratch->{NAME}`. The difference from [set](set.md) is lifetime: the variable
name is pushed onto Interchange's temporary-scratch list and the value is
deleted automatically once the current page has been processed and served. It
never gets written to the session.

Use it to stage a computed value you need only within the current page, without
leaving it behind for later pages (which plain `[set]`/`$Scratch` would) and
without the session write cost.

For a version that does **not** interpolate the body, use
[tmpn](tmpn.md); equivalently, pass `interpolate=0`.

## Examples

Compute today's date once and reuse it on the page:

    [tmp now][time fmt='%Y%m%d'][/tmp]
    Today is [scratch now].

Stage a raw order total for later formatting:

    [tmp raw_total][total-cost noformat=1][/tmp]

## Notes

Despite the name, the value lives in the regular scratch space (`$Scratch`),
not in the `$Tmp` space used by [tv](tv.md)/[ts](ts.md)/[tn](tn.md). If another
tag on the page reads the same scratch name, `[tmp]` will overwrite it for the
remainder of the page; choose distinct names to avoid collisions.

## See also

[tmpn](tmpn.md), [set](set.md), [seti](seti.md), [scratch](scratch.md),
[ts](ts.md), [tv](tv.md), the [templating](../guides/templating.md) guide.

## Source

Defined in `code/SystemTag/tmp.coretag`. Implemented by
`Vend::Interpolate::set_tmp` in `lib/Vend/Interpolate.pm`; the temporary names
are cleared in `Vend::Session`.
