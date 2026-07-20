# else

Marks the fallback branch of an [if](if.md) or [unless](unless.md) block —
the text emitted when the condition (and every [elsif](elsif.md)) failed.
`[else]` is not an independent tag; it is meaningful only inside an
[if](if.md)/[unless](unless.md) body.

## Syntax

    [if type term]
      true branch
    [else]
      false branch
    [/else]
    [/if]

Container-style sub-block: it has a matching `[/else]`. It takes no
attributes.

## Description

When the enclosing [if](if.md) test is true, the `[else]` block (and its
contents) is discarded. When the test is false — and no [elsif](elsif.md)
matched — the text between `[else]` and `[/else]` becomes the tag's output.
For [unless](unless.md) the sense is reversed: `[else]` is emitted when the
`[unless]` condition is true.

`[else]` is optional. An `[if]` with no `[else]` simply produces nothing when
its test fails. There may be at most one `[else]` per `[if]`/`[unless]`
block, and it must come after any [elsif](elsif.md) blocks.

The `[else]`/`[/else]` pair is parsed out of the body by the `[if]`
implementation itself (`split_if` / `find_matching_else` in
`lib/Vend/Interpolate.pm`); Interchange does not register `else` as a
standalone tag, so it does nothing on its own and outside an `[if]` block it
is passed through as literal text.

## Examples

    [if value email]
    Confirmation will be sent to [value email].
    [else]
    No email address on file.
    [/else]
    [/if]

## See also

[if](if.md), [unless](unless.md), [elsif](elsif.md).

## Source

Handled inside `Vend::Interpolate::split_if` and `find_matching_else` in
`lib/Vend/Interpolate.pm`, as part of the [if](if.md) implementation. There
is no separate `else` entry in `%Routine` in `lib/Vend/Parse.pm`.
