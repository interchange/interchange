# strip_html

Removes HTML tags and comments from the value, leaving readable plain text.

## Syntax

    [filter strip_html]TEXT[/filter]
    [value name=field filter="strip_html"]

`strip_html` takes no arguments. It is often chained with a truncation
notation to produce a fixed-length text summary, for example
`filter="strip_html 200."` (see [special-notations](special-notations.md)).

## Description

The filter rewrites the input in several passes:

1. HTML comments (`<!-- ... -->`) are removed.
2. Block-level and container tags are replaced with a single space. This
   covers the opening and closing forms of `p`, `ol`, `ul`, `li`, `div`,
   `h1`–`h6`, `pre`, `dl`, `dd`, `dt`, `form`, `option`, `textarea`, and
   `blockquote`.
3. The self-closing break tags `<br>` and `<hr>` (in any of their forms) are
   replaced with a single space.
4. All remaining tags are removed with no replacement, so inline tags such as
   `<b>` or `<a>` join the surrounding text directly.
5. Whitespace is normalized the way a browser renders it: leading and trailing
   whitespace is trimmed and every internal run of whitespace is collapsed to a
   single space.

The tag matching is a set of regular expressions, not a full HTML parser, so
deliberately malformed markup can survive; for untrusted input that must be
made safe, use [restrict_html](restrict_html.md) instead. Empty input yields
the empty string.

## Examples

Strip inline tags with no added space:

    [filter strip_html]<b>Bold</b> and <i>italic</i>[/filter]

produces:

    Bold and italic

Block tags become word boundaries and whitespace is collapsed:

    [filter strip_html]<p>First</p>

    <p>Second</p>[/filter]

produces:

    First Second

Comments are dropped:

    [filter strip_html]Keep<!-- drop this -->this[/filter]

produces:

    Keepthis

Build a short plain-text teaser from a stored HTML description:

    [filter strip_html 60.][item-field description][/filter]

## See also

- [html2text](html2text.md) — richer HTML-to-text conversion
- [text2html](text2html.md) — the inverse direction (plain text to HTML)
- [restrict_html](restrict_html.md) — keep only an allowed set of tags
- [special-notations](special-notations.md) — truncation notations often
  chained after `strip_html`

## Source

Defined in `code/Filter/strip_html.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
