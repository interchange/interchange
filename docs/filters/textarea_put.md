# textarea_put

Encodes text for safe display inside an HTML `<textarea>`, escaping the
characters that would otherwise break the field or be interpreted as
Interchange Tag Language (ITL).

## Syntax

    [filter textarea_put]TEXT[/filter]
    [value name=field filter="textarea_put"]

`textarea_put` takes no arguments.

## Description

The filter performs three substitutions, in this order:

1. `&` becomes `&amp;` (done first so the entities added below are not
   themselves re-encoded).
2. `[` becomes `&#91;`, which prevents the text from being parsed as an ITL
   tag when the textarea contents are later interpolated.
3. `<` becomes `&lt;`, so the browser does not treat the text as HTML markup.

Note that `>` and `]` are **not** encoded — only the characters that could
prematurely close the surrounding markup or open an ITL tag are escaped. Read
the value back with [textarea_get](textarea_get.md), which reverses the
ampersand encoding.

## Examples

    [filter textarea_put]a & b < c [tag][/filter]

produces:

    a &amp; b &lt; c &#91;tag]

## See also

- [textarea_get](textarea_get.md) — the decoding counterpart
- [encode_entities](encode_entities.md),
  [encode_special_entities](encode_special_entities.md) — general HTML entity
  encoding
- [textarea](../widgets/textarea.md) — the textarea form widget

## Source

Defined in `code/Filter/textarea_put.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
