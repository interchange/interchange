# no_locale_parse

Disables parsing of the `[L]` and `[LC]` localization pseudo-tags. Set it to skip
locale substitution when you do not use Interchange's inline translation markup
and want to avoid the parsing pass.

**Default:** off — `[L]` and `[LC]` are parsed and localized.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma no_locale_parse

Page-wide, anywhere in an Interchange page:

    [pragma no_locale_parse]
    [pragma no_locale_parse 0]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma no_locale_parse]1[/tag]

This is a boolean pragma.

## Description

`parse_locale()` scans page text for the `[L]...[/L]` and `[LC]...[/LC]`
pseudo-tags and replaces them with locale-specific text drawn from the active
[Locale](../config/Locale.md). When `no_locale_parse` is set, `parse_locale()`
returns immediately without scanning, so those pseudo-tags are left untouched.

## Examples

Disable locale parsing catalog-wide for a single-language catalog. In
`catalog.cfg`:

    Pragma no_locale_parse

## Notes

Setting this pragma at the page level is generally not helpful: the `[L]` and
`[LC]` pseudo-tags are parsed early, before an in-page `[pragma]` tag takes
effect. Set it in `catalog.cfg` to reliably suppress locale parsing.

## See also

- [Locale](../config/Locale.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `parse_locale()` in
`lib/Vend/Util.pm`.
