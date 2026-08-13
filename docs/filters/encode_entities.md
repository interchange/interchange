# encode_entities

Encodes HTML-significant and non-printable characters in the value as HTML
character entities.

## Syntax

    [filter encode_entities]TEXT[/filter]
    [filter e]TEXT[/filter]
    [filter entities]TEXT[/filter]
    [value name=field filter="encode_entities"]

`encode_entities` takes no arguments. The short aliases [e](e.md) and
[entities](entities.md) invoke the same filter. It can be used anywhere a
filter is accepted: the [filter](../tags/filter.md) tag, the `filter=`
attribute of tags such as [value](../tags/value.md), and the `filter`
setting of a form widget.

## Description

The filter calls `HTML::Entities::encode` with Interchange's standard
"unsafe character" set (`$ESCAPE_CHARS::std`, defined in
`lib/Vend/Util.pm`). In practice this encodes the HTML-significant
characters `&`, `<`, `>`, and `"`, along with control and high-bit
characters, while leaving ordinary printable ASCII (including the
apostrophe `'`) untouched. It is the inverse of
[decode_entities](decode_entities.md). Empty or undefined input yields the
empty string.

The most common use is to neutralize untrusted CGI input before it is
placed into an HTML page, so that markup a user submits is displayed as
text rather than interpreted by the browser.

## Examples

    [filter encode_entities]One & Two < Three > "quoted"[/filter]

produces:

    One &amp; Two &lt; Three &gt; &quot;quoted&quot;

## See also

- [e](e.md)
- [entities](entities.md)
- [decode_entities](decode_entities.md)
- [encode_special_entities](encode_special_entities.md)
- [strip_html](strip_html.md)

## Source

Defined in `code/Filter/encode_entities.filter`. Uses `HTML::Entities` with
`$ESCAPE_CHARS::std` from `lib/Vend/Util.pm`.
