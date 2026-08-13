# quick_table

Turn a block of `label: value` lines into a simple two-column HTML table, with
labels bold and right-aligned. Reach for it in admin UI pages to lay out a
compact record summary without writing table markup by hand.

`[quick_table]` is part of the admin UI tag set in `code/UI_Tag/`, loaded when
the administrative interface is enabled; it is not a storefront tag.

## Syntax

    [quick_table border]label: value
    another: value[/quick_table]

Container tag (has an end tag). The body **is** interpolated as Interchange Tag
Language (ITL) before the table is built (the tag declares `Interpolate`), so
ITL in the body is expanded first. The return value is an HTML table.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `border` | none | The HTML `BORDER` value for the table. When set, it is emitted as `BORDER=n`; when omitted, no border attribute is written. |

Positional order: `border`.

## Description

`[quick_table]` splits its (already interpolated) body on newlines. Each
non-empty line is split on the first colon (surrounding whitespace trimmed)
into a left label and a right value, producing one table row: the label goes
in a right-aligned, top-aligned cell and the value in a top-aligned cell.

The label is wrapped in `<B>...</B>` unless it already contains a `<`
character, so a label that carries its own markup is left as written. The whole
block is wrapped in `<TABLE ALIGN=LEFT>` (plus `BORDER=n` when `border` is
given).

## Examples

A minimal two-row summary:

    [quick_table]
    SKU: os28057a
    Description: 16 Penny Nails
    [/quick_table]

produces:

    <TABLE ALIGN=LEFT><TR><TD ALIGN=RIGHT VALIGN=TOP><B>SKU</B></TD><TD VALIGN=TOP>os28057a</TD></TR>
    <TR><TD ALIGN=RIGHT VALIGN=TOP><B>Description</B></TD><TD VALIGN=TOP>16 Penny Nails</TD></TR>
    </TABLE>

Because the body is interpolated first, ITL values fill the cells; add a
border with the positional argument:

    [quick_table 1]
    SKU: [item-code]
    Price: [item-price]
    [/quick_table]

## Notes

The generated markup uses uppercase HTML attributes and no CSS classes; it is
meant for quick internal admin layout, not for themed storefront output.

A line with no colon puts the whole line in the label cell and leaves the value
cell empty.

## See also

- Concepts: [templating](../guides/templating.md),
  [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/quick_table.coretag` as an inline `UserTag` Routine
(`UserTag quick_table`, `HasEndTag`, `Interpolate`).
