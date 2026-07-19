# pre

Wraps the value in an HTML `<pre>...</pre>` element.

## Syntax

    [filter pre]TEXT[/filter]
    [value name=field filter="pre"]

## Description

The filter prepends `<pre>` and appends `</pre>` to the value, marking it as
preformatted text so a browser renders it in a monospace font and preserves
its whitespace and line breaks. The content itself is not modified or
escaped; if it may contain HTML metacharacters, apply
[encode_entities](encode_entities.md) first.

## Examples

    [filter pre]Preformatted text[/filter]

produces:

    <pre>Preformatted text</pre>

## See also

[small](small.md), [tt](tt.md), [encode_entities](encode_entities.md)

## Source

Defined in `code/Filter/pre.filter`.
