# tt

Wraps the value in an HTML `<tt>` (teletype/monospace) element.

## Syntax

    [filter tt]TEXT[/filter]
    [value name=field filter="tt"]

`tt` takes no arguments.

## Description

The filter returns its input with `<tt>` prepended and `</tt>` appended. The
input is passed through unchanged and is **not** HTML-escaped, so any markup in
the value is preserved. Empty input yields `<tt></tt>`.

Note that `<tt>` is an obsolete HTML element; modern pages typically use
`<code>`, `<kbd>`, `<samp>`, or a CSS monospace font instead.

## Examples

    [filter tt]make install[/filter]

produces:

    <tt>make install</tt>

## See also

- [pre](pre.md) — wrap in a `<pre>` block (preserves whitespace)
- [strikeout](strikeout.md), [bold](bold.md), [italics](italics.md),
  [small](small.md), [large](large.md) — other HTML-wrapping filters

## Source

Defined in `code/Filter/tt.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
