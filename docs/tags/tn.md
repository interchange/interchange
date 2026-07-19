# tn

Set a truly temporary value in Interchange's `$Tmp` space, storing the body
verbatim (without interpolating it). Read it back with [tv](tv.md). This is the
non-interpolating companion of [ts](ts.md).

## Syntax

    [tn name]VALUE[/tn]

Container tag (has an end tag). Returns an empty string; its effect is the value
it stores.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | none    | Name to store the value under (positional). |

Positional order: `name`.

## Description

`tn` ("temporary set, no interpolation") stores its body exactly as written in
`$Vend::Interpolate::Tmp->{`*name*`}`. Unlike [ts](ts.md), it does *not* expand
ITL in the body first, so any tags are preserved literally. The value is
reachable with [tv](tv.md) or, from embedded Perl, as `$Tmp->{`*name*`}`.

Like the rest of the trio, the `$Tmp` space is request-local and is never saved
to the session, so it will not persist across pages or collide with session
values the way [set](set.md)/[scratch](scratch.md) can.

## Examples

Store an uninterpolated value and display it with [tv](tv.md):

    [tn bar]The time tag is set as in: [time]%H:%M[/time][/tn]
    [tv bar]

produces the literal text, tags and all:

    The time tag is set as in: [time]%H:%M[/time]

## See also

- [tv](tv.md), [ts](ts.md)
- [set](set.md), [scratch](scratch.md), [tmpn](tmpn.md)
- Concepts: [templating](../guides/templating.md),
  [perl embedding](../guides/perl-embedding.md)

## Source

Defined in `code/SystemTag/tv.coretag` as an inline Routine (alongside
[tv](tv.md) and [ts](ts.md)).
