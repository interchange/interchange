# qb_safe

Removes characters that QuickBooks cannot handle in imported data.

## Syntax

    [filter qb_safe]TEXT[/filter]
    [value name=field filter="qb_safe"]

## Description

The filter deletes every double quote (`"`), forward slash (`/`), and
backslash (`\`) from the value. These characters can break a QuickBooks
import, so `qb_safe` strips them before an order or item field is exported
to QuickBooks. All other characters, including spaces, are left intact.

## Examples

    [filter qb_safe]1/2" bolt \ washer[/filter]

produces:

    12 bolt  washer

Combine with a length limit (a bare number is a built-in truncation filter)
to cap the field at 25 characters:

    [filter op="qb_safe 25"]TEXT[/filter]

## See also

[filesafe](filesafe.md), [sql](sql.md)

## Source

Defined in `code/Filter/qb_safe.filter`.
