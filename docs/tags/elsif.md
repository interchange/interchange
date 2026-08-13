# elsif

Adds an additional test to an [if](if.md) or [unless](unless.md) block,
evaluated only when the preceding `[if]` test (and any earlier `[elsif]`)
failed. Like [else](else.md), it is meaningful only inside an
[if](if.md)/[unless](unless.md) body.

## Syntax

    [if type term op compare]
      first branch
    [elsif type term op compare]
      second branch, tested only if the [if] failed
    [/elsif]
    [else]
      final fallback
    [/else]
    [/if]

Container-style sub-block with a matching `[/elsif]`. It takes the same
positional parameters and attributes as [if](if.md): `type`, `term`, `op`,
`compare` (plus their aliases).

## Description

`[elsif]` blocks are tested in source order, each only if every branch before
it was false. The first `[elsif]` whose test succeeds supplies the output;
the rest, and any trailing [else](else.md), are discarded. If none matches,
the [else](else.md) block (if present) is used.

Internally the [if](if.md) implementation rewrites a failed `[if]` with
`[elsif]` blocks into a fresh nested `[if]` and re-parses it, so `[elsif]`
chains resolve one level at a time. `elsif` is not a standalone tag; outside
an `[if]`/`[unless]` body it is passed through as literal text.

## Examples

    [if value payment eq check]
    Mail your check to the address below.
    [elsif value payment eq card]
    Your card will be charged at shipment.
    [elsif value payment eq cod]
    Please have exact payment ready for delivery.
    [else]
    Select a payment method.
    [/else]
    [/if]

## See also

[if](if.md), [unless](unless.md), [else](else.md).

## Source

Handled inside `Vend::Interpolate::split_if` (and `tag_if` /
`tag_self_contained_if`, which re-emit the pertinent `[elsif]` as a nested
`[if]`) in `lib/Vend/Interpolate.pm`, as part of the [if](if.md)
implementation. There is no separate `elsif` entry in `%Routine` in
`lib/Vend/Parse.pm`.
