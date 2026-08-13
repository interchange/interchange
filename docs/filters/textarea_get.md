# textarea_get

Decodes the ampersand entities added by [textarea_put](textarea_put.md),
turning `&amp;` back into a literal `&`.

## Syntax

    [filter textarea_get]TEXT[/filter]
    [value name=field filter="textarea_get"]

`textarea_get` takes no arguments.

## Description

The filter replaces every occurrence of `&amp;` with a literal `&`. It is the
counterpart to [textarea_put](textarea_put.md), which encodes text for safe
display inside an HTML `<textarea>`; `textarea_get` reverses the ampersand
encoding when reading such a value back. Only `&amp;` is decoded — the `&lt;`
and `&#91;` sequences that `textarea_put` produces are **not** reversed by this
filter.

## Examples

    [filter textarea_get]Ben &amp; Jerry&amp;#91;s[/filter]

produces:

    Ben & Jerry&#91;s

(The `&amp;` sequences become `&`; the already-decoded `&#91;` inside
`&amp;#91;` is left as `&#91;`.)

## See also

- [textarea_put](textarea_put.md) — the encoding counterpart
- [decode_entities](decode_entities.md) — decode the full HTML entity set

## Source

Defined in `code/Filter/textarea_get.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
