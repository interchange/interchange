# nullselect

Returns the first non-empty value from a NUL-separated list.

## Syntax

    [value name=field filter="nullselect"]

## Description

Interchange joins the several values of a same-named form control (such as
an HTML combo box, or a select paired with a text input) into a single
string separated by ASCII NUL (`\0`) characters. The `nullselect` filter
splits that string on runs of NUL and returns the first piece that has a
non-zero length, so the user's typed or chosen entry wins over the empty
slots. If every piece is empty it returns the empty string.

This is the combo-box companion to [checkbox](checkbox.md): where a combo
widget submits both a dropdown selection and a free-text field under one
name, `nullselect` picks whichever one the user actually filled in.

## Examples

Given a combo control named `color` that submits an empty dropdown slot
followed by the typed value `teal` (joined internally as
`"\0teal"`), applying the filter:

    [value name=color filter="nullselect"]

produces:

    teal

If the dropdown value `red` is chosen and the text box left blank
(`"red\0"`), the same filter returns:

    red

## Notes

Because the NUL character cannot be typed literally in an Interchange Tag
Language (ITL) page, this filter is only meaningful on values that
Interchange itself has NUL-joined from multivalued form input; it is not
useful on ordinary literal text.

## See also

[checkbox](checkbox.md); often paired with the
[combo](../widgets/combo.md) widget.

## Source

Defined in `code/Filter/nullselect.filter`.
