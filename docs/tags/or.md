# or

Adds an alternative condition, used as a standalone tag immediately inside an
[if](if.md) (or [unless](unless.md)) body. It is the ITL spelling of a
logical OR between two simple tests.

## Syntax

    [if type term op compare]
    [or type term op compare]
    body shown when either test is true
    [/if]

Standalone tag (no end tag of its own). It takes the same parameters as
[if](if.md).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `type`    | (none)  | The kind of thing to test. |
| `term`    | (none)  | What to look up within that type. |
| `op`      | (none)  | Comparison operator; omit to test for truth. |
| `compare` | (none)  | Right-hand side of the comparison. |

Positional order: `type`, `term`, `op`, `compare`.

Aliases: `base` for `type`; `comp` for `compare`; `operator` for `op`. Perl
comparison operators are recognized as an implicit `op`.

## Description

Like [and](and.md), `[or]` is consumed as part of the enclosing [if](if.md)
condition, not evaluated on its own. Each leading `[or ...]` in the `[if]`
body adds an alternative: the body is shown if the primary test **or** any
`[or]` condition is true. The chain short-circuits — the first true test
wins.

`[or]` and [and](and.md) may be mixed, but tests are chained left to right
with no grouping. Use `[if explicit]` or embedded [perl](perl.md) when you
need real boolean precedence (see [if](if.md)).

## Examples

Match either of two names:

    [if value name =~ /Mike/]
    [or value name =~ /Jean/]
    Your name is Mike or Jean.
    [/if]

Accept a customer flagged in either the session or a value:

    [if session vip]
    [or value promo_code eq VIP2026]
    You qualify for the members' discount.
    [/if]

## See also

[if](if.md), [and](and.md), [unless](unless.md); the
[templating](../guides/templating.md) guide.

## Source

Parser built-in defined in `lib/Vend/Parse.pm` (`%Routine`, mapped to
`Vend::Interpolate::tag_self_contained_if` with an extra trailing argument so
the condition is chained rather than emitted). The chaining itself happens in
`Vend::Interpolate::conditional` / `find_andor` in `lib/Vend/Interpolate.pm`.
