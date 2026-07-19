# text2html

Converts plain-text line breaks into HTML `<br>` tags so multi-line text
displays with its line structure in a browser.

## Syntax

    [filter text2html]TEXT[/filter]
    [value name=field filter="text2html"]

`text2html` takes no arguments.

## Description

The filter turns line breaks into `<br>` tags:

- A blank line (a paragraph break — two consecutive newlines in any
  combination of `\r` and `\n`, or a `\r\r`) becomes **two** `<br>` tags.
- Every remaining single newline (`\r\n`, `\n`, or a bare `\r`) becomes **one**
  `<br>` tag.

No other text is altered — HTML metacharacters such as `&`, `<`, and `>` are
left as-is, and the filter does not wrap paragraphs in `<p>` elements.

The exact form of each break tag depends on the catalog's document type: it is
emitted as `<br />` when Interchange is generating XHTML and as `<br>`
otherwise (controlled by the internal `$Vend::Xtrailer` value, set from the
document-type configuration).

> **Note:** older documentation described this filter as wrapping
> double-newlines in a `<p>` tag. The current code instead emits a pair of
> `<br>` tags for a blank line and never produces `<p>`.

## Examples

Assuming a catalog that emits plain `<br>`:

    [filter text2html]Line one
    Line two[/filter]

produces:

    Line one<br>Line two

A blank line becomes two break tags:

    [filter text2html]First paragraph.

    Second paragraph.[/filter]

produces:

    First paragraph.<br><br>Second paragraph.

## See also

- [strip_html](strip_html.md), [html2text](html2text.md) — convert HTML back
  to text
- [pre](pre.md) — wrap text in a `<pre>` block to preserve whitespace instead
- [encode_entities](encode_entities.md) — escape HTML metacharacters (not done
  by `text2html`)

## Source

Defined in `code/Filter/text2html.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`); the break-tag
suffix comes from `$Vend::Xtrailer` (`lib/Vend/Dispatch.pm`).
