# pragma

Sets a [pragma](../pragmas/README.md) for the whole current page,
overriding any catalog-wide `Pragma` setting for the duration of the page.

## Syntax

    [pragma name]
    [pragma name value]

Standalone. With no value, the pragma is set to `1`.

## Description

`[pragma]` is not an ordinary tag: it is extracted during the pre-parse
phase (`vars_and_comments` in `lib/Vend/Interpolate.pm`), before Variable
substitution and tag interpolation, so it takes effect for the *entire*
page no matter where it appears — including pragmas that influence
pre-parse behavior itself. See
[Templating](../guides/templating.md) for the pipeline.

To set a pragma only from that point in the page onward (rare), use
`[tag pragma name]value[/tag]`; to test one, use
`[if pragma name]` ([if](if.md)).

## Examples

    [pragma dynamic_variables]

    [pragma strip_white 0]

## See also

[Pragma reference](../pragmas/README.md), the
[Pragma directive](../config/Pragma.md), [tag](tag.md), [if](if.md)

## Source

Extracted in `vars_and_comments`, `lib/Vend/Interpolate.pm` (~line 602);
runtime forms via the `pragma` handling in `lib/Vend/Interpolate.pm`.
