# e

Alias for [encode_entities](encode_entities.md). See that page for the full
description.

## Syntax

    [filter e]TEXT[/filter]
    [value name=field filter="e"]

`e` is a short alias for the [encode_entities](encode_entities.md) filter;
it encodes HTML-significant and non-printable characters as HTML entities.

## Examples

    [filter e]One & Two < Three[/filter]

produces:

    One &amp; Two &lt; Three

## See also

- [encode_entities](encode_entities.md)
- [entities](entities.md)
- [decode_entities](decode_entities.md)

## Source

Defined as an alias in `code/Filter/encode_entities.filter`
(`CodeDef e Alias encode_entities`).
