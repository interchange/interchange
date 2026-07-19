# decode_entities

Decodes HTML character entities in the value back to their literal
characters.

## Syntax

    [filter decode_entities]TEXT[/filter]
    [value name=field filter="decode_entities"]

`decode_entities` takes no arguments. It can be used anywhere a filter is
accepted: the [filter](../tags/filter.md) tag, the `filter=` attribute
of tags such as [value](../tags/value.md), and the `filter` setting of a
form widget.

## Description

The filter calls `HTML::Entities::decode`, converting named and numeric
HTML entities (for example `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&#233;`)
into the characters they represent. It is the inverse of
[encode_entities](encode_entities.md). Empty or undefined input yields the
empty string.

A common use is as a `pre_filter` on `mv_metadata` fields whose stored
content is HTML-encoded, so the underlying value is decoded before further
processing.

## Examples

    [filter decode_entities]One &amp; Two &lt; Three[/filter]

produces:

    One & Two < Three

## See also

- [encode_entities](encode_entities.md)
- [encode_special_entities](encode_special_entities.md)
- [strip_html](strip_html.md)

## Source

Defined in `code/Filter/decode_entities.filter`. Uses the `HTML::Entities`
Perl module.
