# rotate_table

Transpose an HTML `<table>` in its body, turning rows into columns and columns
into rows. The admin UI uses it to flip a horizontally-laid-out record display
into a vertical one. This tag is part of the admin UI toolset (the tags in
`code/UI_Tag/`, loaded when the admin UI feature is enabled), not a storefront
tag.

## Syntax

    [rotate_table 1]
    <table> ... </table>
    [/rotate_table]

Container tag (processes its body). Its body is interpolated as Interchange Tag
Language (ITL) first, then rotated. When the `rotate` flag is false the body is
returned unchanged.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `rotate`  | none    | When true, transpose the table; when false/absent, return the body untouched. |

Positional order: `rotate` (the single positional parameter).

## Description

The tag scans its body for the first `<table ...>` opening tag and its matching
`</table>`, and rewrites the rows between them. Every `<tr>` in the source
becomes a column of the output, and every cell (`<th>` or `<td>`) becomes a row,
so a table that read left-to-right now reads top-to-bottom. Cell markup is
preserved: `<th>` cells keep their heading type, and `colspan`/`rowspan`
attributes are swapped so a horizontal span becomes a vertical one. Content
before the opening `<table>` tag and after the closing `</table>` is passed
through unchanged.

Because rotation only happens when `rotate` is true, you can drive it from a
variable or CGI flag to make the transposition optional on the same page.

## Examples

Transpose a two-row table:

    [rotate_table 1]
    <table>
    <tr><th>SKU</th><th>Price</th></tr>
    <tr><td>os28004</td><td>15.00</td></tr>
    </table>
    [/rotate_table]

produces a table equivalent to:

    <table>
    <tr><th>SKU</th><td>os28004</td></tr>
    <tr><th>Price</th><td>15.00</td></tr>
    </table>

Make rotation conditional on a request flag (no rotation when `flip` is empty):

    [rotate_table "[cgi flip]"]
    <table>[loop ...]...[/loop]</table>
    [/rotate_table]

## Notes

The tag parses HTML with regular expressions and expects a reasonably simple,
well-formed single `<table>`; deeply nested tables or unusual markup may not
transpose cleanly.

## See also

- [loop](../tags/loop.md)
- Concepts: [admin UI](../guides/admin-ui.md),
  [templating](../guides/templating.md)

## Source

Defined in `code/UI_Tag/rotate_table.coretag` as an inline `UserTag` Routine
(registered `UserTag rotate-table`; hyphen and underscore spellings are
equivalent when invoking the tag).
