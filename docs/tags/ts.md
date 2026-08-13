# ts

Set a truly temporary value in Interchange's `$Tmp` space, interpolating the
body first. Read it back with [tv](tv.md). Use `ts`/[tn](tn.md)/[tv](tv.md)
instead of [set](set.md)/[scratch](scratch.md) when the value is needed only for
the current request and must not touch the session.

## Syntax

    [ts name]VALUE[/ts]

Container tag (has an end tag). Returns an empty string; its effect is the value
it stores.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | none    | Name to store the value under (positional). |

Positional order: `name`.

## Description

`ts` ("temporary set") evaluates its body as ITL — the tag declares
`Interpolate`, so any tags inside are expanded first — and stores the result in
`$Vend::Interpolate::Tmp->{`*name*`}`. The value is reachable with [tv](tv.md)
or, from embedded Perl, as `$Tmp->{`*name*`}`.

The `$Tmp` space is request-local and is never saved to the session, so unlike
[set](set.md)/[scratch](scratch.md) it cannot persist across pages or overwrite
values other pages depend on. Use [tn](tn.md) instead when you want to store the
body *without* interpolating it first.

## Examples

Store an interpolated value and read it back with [tv](tv.md):

    [ts foo]The time is: [time]%H:%M[/time][/ts]
    [tv foo]

produces (for a 09:10 clock):

    The time is: 09:10

## See also

- [tv](tv.md), [tn](tn.md)
- [set](set.md), [scratch](scratch.md), [tmp](tmp.md)
- Concepts: [templating](../guides/templating.md),
  [perl embedding](../guides/perl-embedding.md)

## Source

Defined in `code/SystemTag/tv.coretag` as an inline Routine (alongside
[tv](tv.md) and [tn](tn.md)).
