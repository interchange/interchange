# unless

The negated form of [if](if.md): includes its body when the test is
*false*. Reach for it when the natural reading of a condition is "unless X"
rather than "if not X".

## Syntax

    [unless type term]BODY[/unless]
    [unless type term op compare]BODY[/unless]
    [unless type="type" term="field" op="op" compare="value"]BODY[/unless]

Container tag (has an end tag). The selected branch is reparsed by default.
`[else]` and `[elsif]` sub-blocks work exactly as in [if](if.md).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `type`    | (none)  | The kind of thing to test. |
| `term`    | (none)  | What to look up within that type. |
| `op`      | (none)  | Comparison operator; omit to test for truth. |
| `compare` | (none)  | Right-hand side of the comparison. |

Positional order: `type`, `term`, `op`, `compare`.

Aliases: `base` for `type`; `comp` and `condition` for `compare`; `operator`
for `op`. The Perl comparison operators are recognized as an implicit `op`,
as in [if](if.md).

## Description

`[unless]` accepts exactly the same test types, operators, and sub-blocks as
[if](if.md) — the only difference is that the true and false outcomes are
swapped. Internally the tag negates the condition and calls the same routine,
so `[unless value fname]` is equivalent to `[if !value fname]`.

When an `[else]` (or `[elsif]`) block is present, `[else]` is emitted when
the `[unless]` condition is *true* (i.e. the primary body was suppressed).

## Examples

Prompt only when the visitor has not logged in:

    [unless session logged_in]
    <a href="[area login]">Please sign in</a>.
    [/unless]

Show a shipping notice unless the cart is empty:

    [unless items]
    Your cart is empty.
    [else]
    You have [nitems] item(s) ready to check out.
    [/else]
    [/unless]

Equivalent negations — these two produce the same result:

    [unless value newsletter]Not subscribed.[/unless]
    [if !value newsletter]Not subscribed.[/if]

## See also

[if](if.md), [and](and.md), [or](or.md), [else](else.md),
[elsif](elsif.md); the [templating](../guides/templating.md) guide.

## Source

Parser built-in defined in `lib/Vend/Parse.pm` (`%Routine`, mapped to
`Vend::Interpolate::tag_unless`). `tag_unless` negates the condition and
delegates to `Vend::Interpolate::tag_self_contained_if` (or `tag_if` for the
positional/embedded form) in `lib/Vend/Interpolate.pm`.
