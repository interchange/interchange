# and

Adds a second condition that must *also* be true, used as a standalone tag
immediately inside an [if](if.md) (or [unless](unless.md)) body. It is the
ITL spelling of a logical AND between two simple tests.

## Syntax

    [if type term op compare]
    [and type term op compare]
    body shown only when both tests are true
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

`[and]` is not evaluated on its own. When the enclosing [if](if.md) is
processed, its body is scanned for leading `[and ...]` and `[or ...]` tags;
each becomes an extra condition chained onto the primary test. The `[if]`
body is shown only if the primary test **and** every `[and]` condition are
true. The chain short-circuits, so a false `[and]` stops evaluation.

`[and]` and [or](or.md) may be mixed, but there is no parenthesization —
tests are simply chained left to right. For anything requiring grouped
boolean logic, use `[if explicit]` or embedded [perl](perl.md) instead (see
[if](if.md)).

Written as a bare tag placed just after the `[if]`, `[and]` must appear
before the conditional body text; it is consumed as part of the condition,
not printed.

## Examples

Require both a first and last name:

    [if value fname]
    [and value lname]
    Full name: [value fname] [value lname]
    [else]
    Please enter both your first and last name.
    [/else]
    [/if]

Combine a session flag with a value test:

    [if session logged_in]
    [and value newsletter]
    You are subscribed to the newsletter.
    [/if]

## See also

[if](if.md), [or](or.md), [unless](unless.md); the
[templating](../guides/templating.md) guide.

## Source

Parser built-in defined in `lib/Vend/Parse.pm` (`%Routine`, mapped to
`Vend::Interpolate::tag_self_contained_if` with an extra trailing argument so
the condition is chained rather than emitted). The chaining itself happens in
`Vend::Interpolate::conditional` / `find_andor` in `lib/Vend/Interpolate.pm`.
