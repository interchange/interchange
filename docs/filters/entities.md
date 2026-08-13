# entities

Alias for [encode_entities](encode_entities.md). See that page for the full
description.

## Syntax

    [filter entities]TEXT[/filter]
    [value name=field filter="entities"]

`entities` is an alias for the [encode_entities](encode_entities.md)
filter; it encodes HTML-significant and non-printable characters as HTML
entities.

## Examples

    [filter entities]One & Two < Three[/filter]

produces:

    One &amp; Two &lt; Three

## See also

- [encode_entities](encode_entities.md)
- [e](e.md)
- [decode_entities](decode_entities.md)

## Source

Defined as an alias in `code/Filter/encode_entities.filter`
(`CodeDef entities Alias encode_entities`).
