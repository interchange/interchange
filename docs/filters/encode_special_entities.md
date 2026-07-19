# encode_special_entities

Encodes the four HTML-special characters `"`, `&`, `<`, and `>` in the input
as their named HTML entities, so the text can be placed safely into HTML
output.

## Syntax

    [filter encode_special_entities]TEXT[/filter]
    [value name=field filter="encode_special_entities"]

## Description

The filter performs four substitutions, in this fixed order:

| Character | Replacement |
|-----------|-------------|
| `"`       | `&quot;`    |
| `&`       | `&amp;`     |
| `<`       | `&lt;`      |
| `>`       | `&gt;`      |

Because the `"` → `&quot;` substitution runs *before* the `&` → `&amp;`
substitution, the ampersand introduced by an encoded double quote is itself
re-encoded: a literal `"` in the input becomes `&amp;quot;`, not `&quot;`. A
bare `&` (not part of an inserted `&quot;`) becomes `&amp;` as expected. See
the second example.

Empty input yields empty output. Only these four characters are touched; all
other characters, including single quotes and non-ASCII bytes, pass through
unchanged.

For general entity encoding (all of `HTML::Entities`' repertoire, including
high-bit characters), use [encode_entities](encode_entities.md) instead. To
reverse encoding, use [decode_entities](decode_entities.md).

## Examples

Encoding comparison operators and an ampersand:

    [filter encode_special_entities]5 > 3 & 2 < 4[/filter]

produces:

    5 &gt; 3 &amp; 2 &lt; 4

Double quotes are double-encoded (note the `&amp;quot;` in the result):

    [filter encode_special_entities]<a href="x">Tom & Jerry</a>[/filter]

produces:

    &lt;a href=&amp;quot;x&amp;quot;&gt;Tom &amp; Jerry&lt;/a&gt;

## See also

- [encode_entities](encode_entities.md)
- [decode_entities](decode_entities.md)
- [strip_html](strip_html.md)
- [restrict_html](restrict_html.md)

## Source

Defined in `code/Filter/encode_special_entities.filter`.
