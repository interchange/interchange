# html2text

Performs a simple conversion of HTML to plain text: paragraph and line-break
tags become newlines and all other tags are stripped.

## Syntax

    [filter html2text]HTML[/filter]
    [value name=field filter="html2text"]

## Description

The conversion is two regular-expression passes, in order:

1. Each `<br>` (with optional slash) and each opening or closing `<p ...>` tag,
   together with the whitespace immediately around it, is replaced by a single
   newline.
2. Every remaining tag — anything matching `<` followed by `/`, `!`, or a
   letter, up to the next `>` — is deleted.

The match is case-insensitive. It is a lightweight text-extraction helper, not
a full HTML parser: it does not decode entities (`&amp;` stays `&amp;`), does
not honor lists or tables, and can be fooled by `<` characters that are not
real tags. Attribute-laden tags are removed along with the rest.

## Examples

    [filter html2text]<p>
    Perl is <b>a lot</b> of <u>fun</u>!
    </p>
    <p>See <br>here.</p>[/filter]

produces (leading/trailing newlines from the paragraph tags included):

    Perl is a lot of fun!

    See
    here.

## See also

- [strip_html](strip_html.md)
- [text2html](text2html.md)
- [restrict_html](restrict_html.md)
- [decode_entities](decode_entities.md)

## Source

Defined in `code/Filter/html2text.filter`.
