# gate

Returns the input unchanged when a scratch variable is true, and an empty
string otherwise — a way to conditionally suppress a block of output.

## Syntax

    [filter gate.SCRATCHVAR]TEXT[/filter]
    [value name=field filter="gate"]

## Description

The filter is meant to pass its input through only when a named
[scratch](../glossary.md) variable holds a true value, returning an empty
string when it does not. Scratch variables are per-session values set with the
[set](../tags/set.md) tag (`[set NAME]1[/set]`).

The routine reads two arguments — the value and one variable name — and does:

    return '' unless $::Scratch->{$var};
    return $val;

**Important — argument mismatch in current code.** The variable name the
routine reads (`$var`) is the *second* argument the filter dispatcher passes,
which is the `$tag`/field-name slot, **not** the dotted argument. The dotted
argument (`SCRATCHVAR` in `[filter gate.tide]`) is placed *after* that slot and
is therefore never read. Consequences in current code
(`code/Filter/gate.filter` with `lib/Vend/Interpolate.pm` `filter_value`):

- Via the plain `[filter gate.tide]...[/filter]` tag there is no field name, so
  `$var` is `undef` and the filter tests `$::Scratch->{''}`. The `.tide`
  suffix has no effect.
- When the filter is attached to a field (for example
  `[value name=tide filter=gate]`), `$var` is the *field name* (`tide`), so the
  gate keys off the scratch variable that shares the field's name.

In other words, gate as shipped gates on the field name it is attached to, not
on a dotted argument. See the Notes section.

## Examples

Gate a field's value on a scratch variable of the same name. Here the value of
field `tide` is emitted only if scratch `tide` is true:

    [set tide]1[/set]
    [value name=tide filter="gate"]

With `[set tide]1[/set]`, the value passes through; with `[set tide]0[/set]`
(or the scratch unset), the result is an empty string.

## Notes

Historic documentation shows the form `[filter gate.tide]The Gate is
open.[/filter]`, implying the scratch variable is named by the dotted
argument. That form does **not** work against the current code, because the
routine reads the `$tag` argument rather than the dotted argument (verified by
tracing `filter_value` in `lib/Vend/Interpolate.pm`). If you need to gate an
arbitrary block on a specific scratch variable by name, use an
[if](../tags/if.md) conditional instead:

    [if scratch tide]The Gate is open.[/if]

## See also

- [set](../tags/set.md)
- [if](../tags/if.md)
- [Sessions guide](../guides/sessions.md)

## Source

Defined in `code/Filter/gate.filter`. Argument handling is in
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
