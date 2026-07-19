# available_ups_internal

List the internal ("zone file") UPS shipping tables that exist in the catalog,
as an option string for a select widget. Used in the admin UI shipping setup to
show which UPS zone CSV files are installed. This tag is part of the
Interchange admin UI toolset (the tags in `code/UI_Tag/`, loaded when the admin
UI feature is enabled), not a storefront tag.

## Syntax

    [available_ups_internal]

Standalone tag (no end tag) and no attributes. The return value is a
tab-and-newline option list; it is not reparsed as Interchange Tag Language
(ITL).

## Attributes

This tag takes no attributes or positional parameters.

## Description

`[available_ups_internal]` globs the catalog for files matching
`products/[0-9][0-9][0-9].csv` — the three-digit UPS zone files. For each match
it extracts the numeric basename and emits one line of the form:

    NNN<TAB>NNN

where `NNN` is the zone number used both as the option value and label. If no
matching files exist, the tag returns an empty string.

The output is shaped for a select-widget `passed` option list (value tab
label, one per line), so it is typically fed straight into a widget or
`[loop]`.

## Examples

Build a dropdown of the installed internal UPS zone tables:

    [accessories attribute=ups_zone type=select passed="[available_ups_internal]"]

Given `products/450.csv` and `products/451.csv`, the tag returns:

    450	450
    451	451

## See also

- [available_www_shipping](available_www_shipping.md)
- [read_shipping](read_shipping.md), [write_shipping](write_shipping.md)
- Concepts: [shipping](../guides/shipping.md)

## Source

Defined in `code/UI_Tag/available_ups_internal.coretag`. Implemented by the
inline Routine in that file.
