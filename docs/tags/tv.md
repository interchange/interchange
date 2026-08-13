# tv

Return a truly temporary value previously set with [ts](ts.md) or
[tn](tn.md). The `tv`/`ts`/`tn` trio stores values in Interchange's `$Tmp`
space — like [scratch](scratch.md) but never written to the session — so they
are ideal for short-lived, request-only working values.

## Syntax

    [tv name]

Standalone tag (no end tag). Returns the stored value, or nothing if the name
was never set this request.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | none    | Name of the temporary value to return (positional). |

Positional order: `name`.

## Description

`tv` ("temporary value") reads `$Vend::Interpolate::Tmp->{`*name*`}` and returns
it. Values in that space are set with [ts](ts.md) (interpolating the body first)
or [tn](tn.md) (storing the body verbatim), and are also reachable from embedded
Perl as `$Tmp->{`*name*`}`.

Unlike [set](set.md)/[scratch](scratch.md), which store into
`$Scratch`/`$Session` and can therefore persist and collide with values other
pages rely on, the `$Tmp` space is discarded at the end of the request and is
never saved to the session. Use it when you need a scratch value only for the
duration of the current page.

## Examples

Set a value with [ts](ts.md), then read it back:

    [ts foo]The time is: [time]%H:%M[/time][/ts]
    [tv foo]

If the time is 09:10, `[tv foo]` returns:

    The time is: 09:10

The same value is available in embedded Perl:

    [perl]
        return "Stored: " . $Tmp->{foo};
    [/perl]

## See also

- [ts](ts.md), [tn](tn.md)
- [scratch](scratch.md), [set](set.md), [tmp](tmp.md), [value](value.md)
- Concepts: [templating](../guides/templating.md),
  [perl embedding](../guides/perl-embedding.md)

## Source

Defined in `code/SystemTag/tv.coretag` as an inline Routine (alongside
[ts](ts.md) and [tn](tn.md)).
