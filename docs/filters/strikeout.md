# strikeout

Wraps the value in an HTML `<strike>` element so it renders with a line
through it.

## Syntax

    [filter strikeout]TEXT[/filter]
    [value name=field filter="strikeout"]

`strikeout` is a plain wrapping filter and takes no arguments. Like every
filter it can also be applied through any `filter=` attribute (for example on
[value](value.md), `[data ... filter=]`, or a `[loop]` element) and chained
with other filters by separating names with whitespace.

## Description

The filter returns its input with the literal string `<strike>` prepended and
`</strike>` appended. The input is passed through unchanged between the tags;
it is **not** HTML-escaped, so any markup in the value is preserved verbatim.
Empty input yields an empty pair of tags (`<strike></strike>`).

Note that `<strike>` is an obsolete HTML element; modern pages typically use
`<del>`, `<s>`, or CSS `text-decoration: line-through` instead.

## Examples

Wrap a literal string:

    [filter strikeout]Was $50[/filter]

produces:

    <strike>Was $50</strike>

Strike a product's list price on a flypage:

    [filter strikeout][item-field msrp][/filter]

## See also

- [tt](tt.md), [bold](bold.md), [italics](italics.md), [pre](pre.md) — other
  HTML-wrapping filters
- Interchange Tag Language (ITL) templating: [templating](../guides/templating.md)

## Source

Defined in `code/Filter/strikeout.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
